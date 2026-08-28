import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { PspResolver } from './psp/psp-resolver';

/** Detalhe do estorno (para o Regem imprimir a comanda / o admin exibir). */
export interface EstornoResultado {
  /** true = estorno eletrônico solicitado ao MP; false = dinheiro/já cancelado/falhou. */
  feito: boolean;
  /** credito | debito | voucher | pix | dinheiro | desconhecido. */
  meio: string;
  valorCentavos: number;
  /** id do estorno no MP (quando eletrônico). */
  refundId?: string;
  mensagem: string;
}

export interface CancelamentoResultado {
  status: 'cancelado';
  pedidoId: string;
  estorno: EstornoResultado;
}

/**
 * Cancelamento de pedido do totem COM estorno eletrônico (só TOTAL).
 *
 * Fonte única usada por dois pontos de entrada:
 *  - Admin (relatórios): `POST /relatorios/pedidos/:id/cancelar` (JWT gerente).
 *  - Regem: `POST /sync/regem/pedido-cancelado` (X-Sync-Token).
 *
 * Cartão (Point) / PIX aprovados → estorna no Mercado Pago (`reembolsar`, o
 * GoGeM detém o token). Dinheiro (retirada a receber) → só marca cancelado (a
 * devolução é em espécie no balcão). Idempotente: pedido já cancelado não
 * re-estorna. O `X-Idempotency-Key` do refund evita estorno duplicado no MP.
 */
@Injectable()
export class CancelamentoService {
  private readonly logger = new Logger(CancelamentoService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly psp: PspResolver,
    private readonly auditoria: AuditoriaService,
  ) {}

  /** Cancela por id do Pedido (admin/relatórios). */
  async cancelarPorId(
    id: string,
    motivo: string,
    origem: string,
  ): Promise<CancelamentoResultado> {
    const pedido = await this.prisma.pedido.findFirst({ where: { id } });
    if (!pedido) throw new NotFoundException('Pedido não encontrado.');
    return this.executar(pedido, motivo, origem);
  }

  /** Cancela por idempotencyKey (ou regemComandaId) — inbound do Regem. */
  async cancelarPorChave(
    chave: { idempotencyKey?: string; regemComandaId?: string },
    motivo: string,
    origem: string,
  ): Promise<CancelamentoResultado> {
    const where: Prisma.PedidoWhereInput | null = chave.idempotencyKey
      ? { idempotencyKey: chave.idempotencyKey }
      : chave.regemComandaId
        ? { regemComandaId: chave.regemComandaId }
        : null;
    if (!where) {
      throw new BadRequestException(
        'Informe idempotencyKey ou regemComandaId.',
      );
    }
    const pedido = await this.prisma.pedido.findFirst({ where });
    if (!pedido) throw new NotFoundException('Pedido não encontrado.');
    return this.executar(pedido, motivo, origem);
  }

  private async executar(
    pedido: {
      id: string;
      idempotencyKey: string;
      status: string;
      totalCentavos: number;
    },
    motivo: string,
    origem: string,
  ): Promise<CancelamentoResultado> {
    // Idempotente: já cancelado → devolve o estado sem re-estornar.
    if (pedido.status === 'cancelado') {
      return {
        status: 'cancelado',
        pedidoId: pedido.id,
        estorno: {
          feito: false,
          meio: 'desconhecido',
          valorCentavos: pedido.totalCentavos,
          mensagem: 'Pedido já estava cancelado.',
        },
      };
    }

    const estorno = await this.estornar(
      pedido.idempotencyKey,
      pedido.totalCentavos,
    );

    // Marca cancelado mesmo se o estorno falhar (o Regem já cancelou o lado dele;
    // o `estorno.feito=false` avisa que o refund não saiu — tratar manualmente).
    await this.prisma.pedido.update({
      where: { id: pedido.id },
      data: {
        status: 'cancelado',
        canceladoEm: new Date(),
        canceladoMotivo: motivo,
      },
    });
    await this.auditoria.registrar({
      acao: 'pedido.cancelar',
      recurso: 'pedido',
      recursoId: pedido.id,
      detalhe: { motivo, origem, estorno },
    });
    return { status: 'cancelado', pedidoId: pedido.id, estorno };
  }

  /** Estorna o pagamento eletrônico aprovado (cartão Point ou PIX). Só total. */
  private async estornar(
    idempotencyKey: string,
    totalCentavos: number,
  ): Promise<EstornoResultado> {
    // Cartão (Point) aprovado?
    const point = await this.prisma.pointPayment.findFirst({
      where: { orderId: idempotencyKey },
    });
    if (point?.status === 'approved' && point.paymentId) {
      const est = await this.chamarRefund(
        point.paymentId,
        idempotencyKey,
        point.tipo ?? 'credito',
        point.amountCents,
      );
      if (est.feito) {
        await this.prisma.pointPayment.update({
          where: { id: point.id },
          data: { status: 'refunded' },
        });
      }
      return est;
    }

    // PIX aprovado?
    const pix = await this.prisma.pixCharge.findFirst({
      where: { orderId: idempotencyKey },
    });
    if (pix?.status === 'approved' && pix.pspRef) {
      const est = await this.chamarRefund(
        pix.pspRef,
        idempotencyKey,
        'pix',
        pix.amountCents,
      );
      if (est.feito) {
        await this.prisma.pixCharge.update({
          where: { id: pix.id },
          data: { status: 'refunded' },
        });
      }
      return est;
    }

    // Dinheiro / sem pagamento eletrônico aprovado.
    return {
      feito: false,
      meio: 'dinheiro',
      valorCentavos: totalCentavos,
      mensagem:
        'Sem pagamento eletrônico a estornar (dinheiro/retirada — devolver no balcão).',
    };
  }

  private async chamarRefund(
    paymentId: string,
    idempotencyKey: string,
    meio: string,
    valorCentavos: number,
  ): Promise<EstornoResultado> {
    try {
      const gw = await this.psp.resolver();
      const r = await gw.reembolsar(paymentId, `refund_${idempotencyKey}`);
      return {
        feito: true,
        meio,
        valorCentavos,
        refundId: r.refundId,
        mensagem:
          'Estorno solicitado ao Mercado Pago (cai na fatura/conta em alguns dias).',
      };
    } catch (err) {
      const m = err instanceof Error ? err.message : String(err);
      this.logger.warn(`Estorno falhou (payment ${paymentId}): ${m}`);
      return {
        feito: false,
        meio,
        valorCentavos,
        mensagem: `Cancelado, mas o estorno eletrônico falhou: ${m}`,
      };
    }
  }
}
