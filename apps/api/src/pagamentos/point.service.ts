import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { CriarPointDto } from './dto/criar-point.dto';
import {
  listarPointDevices,
  MercadoPagoPointGateway,
  parsePointWebhook,
  type PointDevice,
} from './psp/mercadopago-point.gateway';
import { PspResolver } from './psp/psp-resolver';

/** Cobrança Point como o totem enxerga (nunca expõe token/intentId). */
export interface PointView {
  id: string;
  status: string;
  amountCents: number;
  tipo: string;
}

/**
 * PointService — cartão na maquininha Point Smart (modo PDV). Multi-tenant pelo
 * middleware do Prisma (o device abre o contexto pelo X-Device-Token). Espelha o
 * PixService: criar → polling do status → webhook re-consulta no contexto do
 * tenant da cobrança. Idempotente por orderId.
 */
@Injectable()
export class PointService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pspResolver: PspResolver,
  ) {}

  /** Lista as maquininhas Point da conta (admin escolhe o device_id). */
  async listarDevices(): Promise<PointDevice[]> {
    const token = await this.pspResolver.tokenMercadoPago();
    if (!token) {
      throw new BadRequestException(
        'Configure o Access Token do Mercado Pago antes de buscar maquininhas.',
      );
    }
    return listarPointDevices(token);
  }

  async criar(dto: CriarPointDto, totemId?: string): Promise<PointView> {
    // Multi-terminal: usa a maquininha vinculada AO totem que está cobrando
    // (fallback = device_id padrão da loja). Assim 4 totens cobram cada um na sua.
    let maquininha: string | null = null;
    if (totemId) {
      const totem = await this.prisma.dispositivo.findFirst({
        where: { id: totemId },
        select: { pointDeviceId: true },
      });
      maquininha = totem?.pointDeviceId ?? null;
    }
    const gw = await this.pspResolver.resolverPoint(maquininha);
    if (!gw) {
      throw new BadRequestException(
        'Point Smart não configurada: vincule a maquininha a este totem (ou defina o device_id padrão da loja).',
      );
    }

    const existente = await this.prisma.pointPayment.findFirst({
      where: { orderId: dto.orderId },
    });
    // Reaproveita: já aprovado, ou pendente (a maquininha já está com a intent).
    if (
      existente &&
      (existente.status === 'approved' || existente.status === 'pending')
    ) {
      return this._view(existente);
    }

    await gw.garantirModoPdv();
    const tipo = dto.tipo ?? 'credit';
    const intent = await gw.criarIntent({
      amountCents: dto.amountCents,
      orderId: dto.orderId,
      tipo,
    });

    if (existente) {
      const upd = await this.prisma.pointPayment.update({
        where: { id: existente.id },
        data: {
          deviceId: gw.deviceId,
          intentId: intent.intentId,
          amountCents: dto.amountCents,
          tipo,
          status: 'pending',
          paymentId: null,
        },
      });
      await this.registrar(upd, 'reuso');
      return this._view(upd);
    }

    const data = {
      orderId: dto.orderId,
      deviceId: gw.deviceId,
      intentId: intent.intentId,
      amountCents: dto.amountCents,
      tipo,
      status: 'pending',
    } satisfies Omit<Prisma.PointPaymentUncheckedCreateInput, 'tenantId'>;
    const criado = await this.prisma.pointPayment.create({
      data: data as Prisma.PointPaymentUncheckedCreateInput,
    });
    await this.registrar(criado, 'criar');
    return this._view(criado);
  }

  /**
   * F10 — grava um evento no journal append-only. Best-effort: NUNCA lança (o
   * journal é auditoria, não pode derrubar a cobrança). O tenantId é injetado
   * pelo middleware (o create roda no contexto do tenant da cobrança).
   */
  private async registrar(
    p: Prisma.PointPaymentGetPayload<object>,
    origem: string,
  ): Promise<void> {
    try {
      const data = {
        pointPaymentId: p.id,
        orderId: p.orderId,
        deviceId: p.deviceId,
        intentId: p.intentId,
        amountCents: p.amountCents,
        tipo: p.tipo,
        bandeira: p.bandeira,
        status: p.status,
        paymentId: p.paymentId,
        origem,
      } satisfies Omit<Prisma.PointJournalUncheckedCreateInput, 'tenantId'>;
      await this.prisma.pointJournal.create({
        data: data as Prisma.PointJournalUncheckedCreateInput,
      });
    } catch {
      /* journal é best-effort — não bloqueia o fluxo de pagamento */
    }
  }

  /** F10 — journal (append-only) das transações Point, p/ reconciliação. Por
   * orderId (ordem cronológica) ou os mais recentes da loja. */
  async journal(
    orderId?: string,
    limite = 200,
  ): Promise<Prisma.PointJournalGetPayload<object>[]> {
    return this.prisma.pointJournal.findMany({
      where: orderId ? { orderId } : {},
      orderBy: { createdAt: orderId ? 'asc' : 'desc' },
      take: Math.min(Math.max(limite, 1), 500),
    });
  }

  async status(id: string): Promise<PointView> {
    const p = await this.prisma.pointPayment.findFirst({ where: { id } });
    if (!p) throw new NotFoundException('Cobrança Point não encontrada.');
    // Gateway com a maquininha DA cobrança (não a padrão da loja).
    const gw = await this.pspResolver.resolverPoint(p.deviceId);
    return this._view(await this._reconciliar(p, gw));
  }

  /** F10: status por orderId (recuperação no boot). null = não há cobrança. */
  async statusPorOrder(orderId: string): Promise<PointView | null> {
    const p = await this.prisma.pointPayment.findFirst({ where: { orderId } });
    if (!p) return null;
    const gw = await this.pspResolver.resolverPoint(p.deviceId);
    return this._view(await this._reconciliar(p, gw));
  }

  async cancelar(id: string): Promise<PointView> {
    const p = await this.prisma.pointPayment.findFirst({ where: { id } });
    if (!p) throw new NotFoundException('Cobrança Point não encontrada.');
    if (p.status === 'pending') {
      const gw = await this.pspResolver.resolverPoint(p.deviceId);
      if (gw && p.intentId) await gw.cancelar(p.intentId);
      const cancelado = await this.prisma.pointPayment.update({
        where: { id: p.id },
        data: { status: 'cancelled' },
      });
      await this.registrar(cancelado, 'cancelar');
      return this._view(cancelado);
    }
    return this._view(p);
  }

  async webhook(
    body: unknown,
    query: Record<string, unknown>,
  ): Promise<{ ok: true }> {
    const parsed = parsePointWebhook(body, query);
    if (parsed) {
      await TenantContext.runAsSystem(async () => {
        const p = await this.prisma.pointPayment.findFirst({
          where: { intentId: parsed.intentId },
        });
        if (!p) return;
        await TenantContext.run({ tenantId: p.tenantId }, async () => {
          const gw = await this.pspResolver.resolverPoint(p.deviceId);
          await this._reconciliar(p, gw);
        });
      });
    }
    return { ok: true };
  }

  private async _reconciliar(
    p: Prisma.PointPaymentGetPayload<object>,
    gw: MercadoPagoPointGateway | null,
  ): Promise<Prisma.PointPaymentGetPayload<object>> {
    if (p.status !== 'pending' || !gw || !p.intentId) return p;
    const r = await gw.consultar(p.intentId);
    if (r.status === p.status) return p;
    // Aprovado: o cliente escolheu a forma NA maquininha (crédito/débito/
    // voucher) — busca a forma REAL uma vez e grava por cima do placeholder
    // (relatório de taxas fiel). Se o MP não responder, mantém o placeholder.
    let tipo = p.tipo;
    let bandeira = p.bandeira;
    if (r.status === 'approved' && r.paymentId) {
      try {
        const pg = await gw.consultarPagamento(r.paymentId);
        if (pg.tipo) tipo = pg.tipo;
        if (pg.bandeira) bandeira = pg.bandeira;
      } catch {
        /* mantém o placeholder — não bloqueia a confirmação do pagamento */
      }
    }
    const atualizado = await this.prisma.pointPayment.update({
      where: { id: p.id },
      data: {
        status: r.status,
        paymentId: r.paymentId ?? p.paymentId,
        tipo,
        bandeira,
      },
    });
    await this.registrar(atualizado, 'reconciliacao');
    return atualizado;
  }

  private _view(p: Prisma.PointPaymentGetPayload<object>): PointView {
    return {
      id: p.id,
      status: p.status,
      amountCents: p.amountCents,
      tipo: p.tipo,
    };
  }
}
