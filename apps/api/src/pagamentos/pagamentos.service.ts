import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { CriarPixDto } from './dto/criar-pix.dto';
import { PspGateway } from './psp/psp-gateway';
import { PspResolver } from './psp/psp-resolver';
import { parseMercadoPagoWebhook } from './psp/mercadopago-psp.gateway';

/** Cobrança PIX como o totem enxerga (nunca expõe credencial/pspRef). */
export interface PixChargeView {
  id: string;
  status: string;
  copiaECola: string | null;
  qrImage: string | null;
  expiresAt: Date | null;
  amountCents: number;
}

/**
 * PagamentosService — PIX via PSP (F8). Multi-tenant pelo middleware do Prisma
 * (as queries em modelo scoped já entram com o tenant do contexto — o device
 * abre o contexto pelo X-Device-Token). O webhook (sem contexto) roda em
 * runAsSystem e casa a cobrança pelo `pspRef` cross-tenant.
 */
@Injectable()
export class PagamentosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pspResolver: PspResolver,
  ) {}

  /** Cria (ou reaproveita) a cobrança do pedido. Idempotente por orderId. */
  async criarPix(dto: CriarPixDto): Promise<PixChargeView> {
    const existente = await this.prisma.pixCharge.findFirst({
      where: { orderId: dto.orderId },
    });
    if (existente) {
      // Já aprovado, ou pendente e ainda válido → devolve o mesmo QR.
      const valido = !existente.expiresAt || existente.expiresAt > new Date();
      if (
        existente.status === 'approved' ||
        (existente.status === 'pending' && valido)
      ) {
        return this._view(existente);
      }
    }

    const psp = await this.pspResolver.resolver();
    const criado = await psp.criarPix({
      amountCents: dto.amountCents,
      orderId: dto.orderId,
      descricao: dto.descricao,
      cpfCnpj: dto.cpfCnpj,
    });

    if (existente) {
      const atualizado = await this.prisma.pixCharge.update({
        where: { id: existente.id },
        data: {
          amountCents: dto.amountCents,
          status: 'pending',
          psp: psp.nome,
          pspRef: criado.pspRef,
          copiaECola: criado.copiaECola,
          qrImage: criado.qrImage,
          expiresAt: criado.expiresAt,
        },
      });
      return this._view(atualizado);
    }

    const data = {
      orderId: dto.orderId,
      amountCents: dto.amountCents,
      status: 'pending',
      psp: psp.nome,
      pspRef: criado.pspRef,
      copiaECola: criado.copiaECola,
      qrImage: criado.qrImage,
      expiresAt: criado.expiresAt,
    } satisfies Omit<Prisma.PixChargeUncheckedCreateInput, 'tenantId'>;
    const charge = await this.prisma.pixCharge.create({
      data: data as Prisma.PixChargeUncheckedCreateInput,
    });
    return this._view(charge);
  }

  /** Status atual (re-consulta o PSP se ainda pendente). */
  async statusPix(id: string): Promise<PixChargeView> {
    const charge = await this.prisma.pixCharge.findFirst({ where: { id } });
    if (!charge) throw new NotFoundException('Cobrança PIX não encontrada.');
    const psp = await this.pspResolver.resolver();
    return this._view(await this._reconciliar(charge, psp));
  }

  /** F10: status PIX por orderId (recuperação no boot). null = não há. */
  async statusPixPorOrder(orderId: string): Promise<PixChargeView | null> {
    const charge = await this.prisma.pixCharge.findFirst({
      where: { orderId },
    });
    if (!charge) return null;
    const psp = await this.pspResolver.resolver();
    return this._view(await this._reconciliar(charge, psp));
  }

  /**
   * Webhook do PSP: casa por pspRef (cross-tenant, runAsSystem) e re-consulta o
   * status DENTRO do contexto do tenant da cobrança (para usar as credenciais
   * dele). Nunca confia no corpo — só extrai a referência.
   */
  async webhook(
    body: unknown,
    query: Record<string, unknown>,
  ): Promise<{ ok: true }> {
    const parsed = parseMercadoPagoWebhook(body, query);
    if (parsed) {
      await TenantContext.runAsSystem(async () => {
        const charge = await this.prisma.pixCharge.findFirst({
          where: { pspRef: parsed.pspRef },
        });
        if (!charge) return;
        await TenantContext.run({ tenantId: charge.tenantId }, async () => {
          const psp = await this.pspResolver.resolver();
          await this._reconciliar(charge, psp);
        });
      });
    }
    return { ok: true };
  }

  private async _reconciliar(
    charge: Prisma.PixChargeGetPayload<object>,
    psp: PspGateway,
  ): Promise<Prisma.PixChargeGetPayload<object>> {
    if (charge.status !== 'pending') return charge;
    if (charge.expiresAt && charge.expiresAt < new Date()) {
      return this.prisma.pixCharge.update({
        where: { id: charge.id },
        data: { status: 'expired' },
      });
    }
    if (!charge.pspRef) return charge;
    const st = await psp.consultar(charge.pspRef);
    if (st !== charge.status) {
      return this.prisma.pixCharge.update({
        where: { id: charge.id },
        data: { status: st },
      });
    }
    return charge;
  }

  private _view(c: Prisma.PixChargeGetPayload<object>): PixChargeView {
    return {
      id: c.id,
      status: c.status,
      copiaECola: c.copiaECola,
      qrImage: c.qrImage,
      expiresAt: c.expiresAt,
      amountCents: c.amountCents,
    };
  }
}
