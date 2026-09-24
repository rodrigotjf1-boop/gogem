import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import {
  RegemRecusouError,
  RegemSalesClient,
} from '../integracoes/regem/regem-sales.client';
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

/** O que o Regem disse do cancelamento feito pelo painel (ERR-016). */
export interface AvisoRegem {
  /** true = o Regem desfez a venda (ou não a conhecia); false = o operador cancela lá. */
  avisado: boolean;
  notaCancelada?: boolean;
  cancelamentoPendente?: boolean;
  mensagem: string;
}

export interface CancelamentoResultado {
  status: 'cancelado';
  pedidoId: string;
  estorno: EstornoResultado;
  /** Só no cancelamento pelo painel de loja integrada ao Regem. */
  regem?: AvisoRegem;
}

function jaEstornado(meio: string, valorCentavos: number): EstornoResultado {
  return {
    feito: true,
    meio,
    valorCentavos,
    mensagem: 'Estorno já solicitado ao Mercado Pago anteriormente.',
  };
}

/**
 * Até quando, depois do pagamento, o TOTEM ainda pode pedir o estorno. O painel não tem prazo
 * (é o gerente, com login); o totem tem — o token do aparelho mora nele, e sem prazo quem o
 * extraísse poderia estornar o histórico inteiro de vendas. 72 h cobrem um fim de semana com
 * o servidor da loja fora (a fila do totem reenvia a venda e só então sabe da nota).
 */
export const PRAZO_ESTORNO_TOTEM_MS = 72 * 60 * 60 * 1000;

/** Opções do estorno por `orderId`. */
export interface EstornoPorOrderOpcoes {
  /** Prazo máximo desde o pagamento (só o caminho do totem passa). */
  prazoMs?: number;
  /** Etapa que falhou (vai para a auditoria). */
  etapa?: string;
  /**
   * Servidor da loja: a nuvem não tem o pedido (ele nasceu no Regem da loja). Estes dados
   * compõem o registro cancelado que o relatório do GoGeM mostra.
   */
  registro?: {
    dispositivoId?: string | null;
    senha?: number | null;
    itens?: unknown[];
  };
}

/** O pagamento eletrônico de um pedido (cartão na Point ou PIX), se houver. */
interface PagamentoDoPedido {
  meio: string;
  valorCentavos: number;
  criadoEm: Date;
}

/**
 * Cancelamento de pedido do totem COM estorno eletrônico (só TOTAL).
 *
 * Fonte única usada pelos pontos de entrada:
 *  - Admin (relatórios): `POST /relatorios/pedidos/:id/cancelar` (JWT gerente).
 *  - Regem: `POST /sync/regem/pedido-cancelado` (X-Sync-Token).
 *  - Totem: `POST /pagamentos/estorno` (X-Device-Token) — a nota não saiu ou o cupom
 *    fiscal não imprimiu; no servidor da loja chega pelo repasse do Regem.
 *  - Venda na nuvem: o Regem respondeu `nao_emitida` (o `VendasService` estorna na hora).
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
    private readonly regem: RegemSalesClient,
  ) {}

  /** Cancela por id do Pedido (sem avisar o Regem — ver `cancelarPeloPainel`). */
  async cancelarPorId(
    id: string,
    motivo: string,
    origem: string,
  ): Promise<CancelamentoResultado> {
    const pedido = await this.prisma.pedido.findFirst({ where: { id } });
    if (!pedido) throw new NotFoundException('Pedido não encontrado.');
    return this.executar(pedido, motivo, origem);
  }

  /**
   * Cancelamento pelo PAINEL (relatórios): o Regem desfaz a venda PRIMEIRO, e só então o
   * dinheiro volta ao cliente (ERR-016). Antes o painel estornava e o Regem seguia com a
   * venda valendo — faturamento, estoque e caixa de uma venda que não existia mais.
   *  - Regem recusa (nota fora do prazo, pedido já cobrado no caixa) → 422 com o motivo,
   *    NADA estornado: o operador resolve no Regem;
   *  - Regem fora do ar → 503, nada estornado;
   *  - Regem sem a rota (versão antiga) → cancela e estorna aqui, e avisa o operador para
   *    cancelar também no Regem (o comportamento de antes, agora dito na tela).
   */
  async cancelarPeloPainel(
    id: string,
    motivo: string,
  ): Promise<CancelamentoResultado> {
    const pedido = await this.prisma.pedido.findFirst({ where: { id } });
    if (!pedido) throw new NotFoundException('Pedido não encontrado.');
    if (pedido.status === 'cancelado') {
      return this.executar(pedido, motivo, 'admin');
    }
    const regem = await this.avisarRegem(pedido.idempotencyKey, motivo);
    const r = await this.executar(pedido, motivo, 'admin');
    return regem ? { ...r, regem } : r;
  }

  private async avisarRegem(
    idempotencyKey: string,
    motivo: string,
  ): Promise<AvisoRegem | undefined> {
    let r: Awaited<ReturnType<RegemSalesClient['cancelarVendaExterna']>>;
    try {
      r = await this.regem.cancelarVendaExterna({
        idempotencyKey,
        motivo: `Cancelado no painel do GoGeM: ${motivo}`.slice(0, 255),
      });
    } catch (err) {
      if (err instanceof RegemRecusouError) {
        throw new UnprocessableEntityException(
          `O Regem não cancelou a venda: ${err.motivo}. Nada foi estornado — resolva no Regem.`,
        );
      }
      const m = err instanceof Error ? err.message : String(err);
      this.logger.warn(
        `Cancelamento no Regem falhou (${idempotencyKey}): ${m}`,
      );
      throw new ServiceUnavailableException(
        'O sistema da loja (Regem) não respondeu. Nada foi cancelado nem estornado — tente de novo em instantes.',
      );
    }
    switch (r.status) {
      case 'sem_integracao':
        return undefined;
      case 'rota_ausente':
        return {
          avisado: false,
          mensagem:
            'O Regem desta loja ainda não recebe o cancelamento pelo GoGeM: cancele a venda também no Regem.',
        };
      case 'cancelada':
        return {
          avisado: true,
          notaCancelada: r.notaCancelada,
          cancelamentoPendente: r.cancelamentoPendente,
          mensagem: !r.encontrada
            ? 'O Regem não tinha esta venda — nada a desfazer lá.'
            : r.cancelamentoPendente
              ? 'Venda desfeita no Regem; a NFC-e será cancelada assim que a SEFAZ autorizar a contingência.'
              : r.notaCancelada
                ? 'Venda desfeita no Regem e NFC-e cancelada.'
                : 'Venda desfeita no Regem.',
        };
    }
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

  /**
   * Estorno pelo `orderId` do pagamento (= uuid do pedido no totem).
   *
   * É o caminho do resultado fiscal: pagamento aprovado, mas a nota não saiu (`nao_emitida`)
   * ou o cupom fiscal não imprimiu. O Regem já desfez a venda do lado dele; aqui o dinheiro
   * volta ao cliente e o motivo fica no relatório. Funciona nos DOIS modos:
   *  - nuvem: existe o `Pedido` → cancela com o motivo e estorna;
   *  - servidor da loja: a nuvem só conhece o PAGAMENTO (a venda mora no Regem da loja) →
   *    estorna e cria o pedido já cancelado, para o relatório do GoGeM registrar o motivo.
   * Idempotente: pedir de novo não estorna duas vezes nem duplica o registro.
   */
  async estornarPorOrder(
    orderId: string,
    motivo: string,
    origem: string,
    opcoes: EstornoPorOrderOpcoes = {},
  ): Promise<{ pedidoId: string | null; estorno: EstornoResultado }> {
    const pagamento = await this.pagamentoDe(orderId);
    if (
      opcoes.prazoMs &&
      pagamento &&
      Date.now() - pagamento.criadoEm.getTime() > opcoes.prazoMs
    ) {
      throw new UnprocessableEntityException(
        'Pagamento antigo demais para o estorno pelo totem — cancele pelo painel (Relatórios).',
      );
    }

    const pedido = await this.prisma.pedido.findFirst({
      where: { idempotencyKey: orderId },
    });
    if (pedido) {
      const r = await this.executar(pedido, motivo, origem, opcoes.etapa);
      return { pedidoId: r.pedidoId, estorno: r.estorno };
    }
    if (!pagamento) {
      // Nada foi cobrado na nuvem com este orderId (ex.: TEF direto no pinpad): o GoGeM não
      // tem como devolver. Sem registro — não há venda nem pagamento para contar.
      return {
        pedidoId: null,
        estorno: {
          feito: false,
          meio: 'desconhecido',
          valorCentavos: 0,
          mensagem:
            'Nenhum pagamento eletrônico do GoGeM encontrado para este pedido — estorno manual.',
        },
      };
    }

    const estorno = await this.estornar(orderId, pagamento.valorCentavos);
    const registrado = await this.registrarCancelado(
      orderId,
      motivo,
      pagamento,
      opcoes.registro,
    );
    await this.auditoria.registrar({
      acao: 'pedido.cancelar',
      recurso: 'pedido',
      recursoId: registrado?.id ?? orderId,
      detalhe: { motivo, origem, etapa: opcoes.etapa, orderId, estorno },
    });
    return { pedidoId: registrado?.id ?? null, estorno };
  }

  /** O pagamento eletrônico do pedido na nuvem (Point ou PIX), em qualquer status. */
  private async pagamentoDe(
    orderId: string,
  ): Promise<PagamentoDoPedido | null> {
    const point = await this.prisma.pointPayment.findFirst({
      where: { orderId },
    });
    if (point) {
      return {
        meio: point.tipo ?? 'credito',
        valorCentavos: point.amountCents,
        criadoEm: point.createdAt,
      };
    }
    const pix = await this.prisma.pixCharge.findFirst({ where: { orderId } });
    if (pix) {
      return {
        meio: 'pix',
        valorCentavos: pix.amountCents,
        criadoEm: pix.createdAt,
      };
    }
    return null;
  }

  /**
   * Servidor da loja: o pedido nasce na nuvem JÁ cancelado, com o motivo — é assim que o
   * estorno aparece no relatório do GoGeM (a venda em si mora no Regem da loja). Corrida com
   * outro pedido de estorno do mesmo `orderId`: a unique `(tenant, idempotencyKey)` barra o
   * segundo, que devolve o registro do primeiro.
   */
  private async registrarCancelado(
    orderId: string,
    motivo: string,
    pagamento: PagamentoDoPedido,
    registro?: EstornoPorOrderOpcoes['registro'],
  ): Promise<{ id: string } | null> {
    const data = {
      idempotencyKey: orderId,
      status: 'cancelado',
      canceladoEm: new Date(),
      canceladoMotivo: motivo,
      dispositivoId: registro?.dispositivoId ?? null,
      senhaLocal: registro?.senha ?? null,
      itens: (registro?.itens ?? []) as Prisma.InputJsonValue,
      pagamentos: [
        { forma: pagamento.meio, valor: pagamento.valorCentavos },
      ] as Prisma.InputJsonValue,
      totalCentavos: pagamento.valorCentavos,
    } satisfies Omit<Prisma.PedidoUncheckedCreateInput, 'tenantId'>;
    try {
      return await this.prisma.pedido.create({
        data: data as Prisma.PedidoUncheckedCreateInput,
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        return this.prisma.pedido.findFirst({
          where: { idempotencyKey: orderId },
        });
      }
      throw err;
    }
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
    etapa?: string,
  ): Promise<CancelamentoResultado> {
    // Já cancelado: devolve o estado REAL do pagamento. Estornado → feito (sem chamar o MP);
    // aprovado com um estorno anterior que falhou → tenta de novo (o `X-Idempotency-Key`
    // do refund impede estorno em dobro). Antes respondia "já estava cancelado" com
    // feito=false, e quem pediu entendia que o dinheiro não tinha voltado.
    if (pedido.status === 'cancelado') {
      const estorno = await this.estornar(
        pedido.idempotencyKey,
        pedido.totalCentavos,
      );
      if (estorno.refundId) {
        // O estorno saiu AGORA (o da primeira vez tinha falhado): fica na trilha.
        await this.auditoria.registrar({
          acao: 'pedido.estornar',
          recurso: 'pedido',
          recursoId: pedido.id,
          detalhe: { motivo, origem, etapa, estorno },
        });
      }
      return { status: 'cancelado', pedidoId: pedido.id, estorno };
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
      detalhe: { motivo, origem, etapa, estorno },
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
    // Já estornado (pelo totem, pelo admin ou pelo Regem): é SUCESSO, não "sem pagamento
    // eletrônico" — antes, pedir de novo dizia ao operador para devolver no balcão um
    // dinheiro que já tinha voltado para o cartão.
    if (point?.status === 'refunded') {
      return jaEstornado(point.tipo ?? 'credito', point.amountCents);
    }
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
    if (pix?.status === 'refunded') return jaEstornado('pix', pix.amountCents);
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
