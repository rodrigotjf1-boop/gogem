import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { CriarPixDto } from './dto/criar-pix.dto';
import { PSP_GATEWAY, PspGateway } from './psp/psp-gateway';

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
    @Inject(PSP_GATEWAY) private readonly psp: PspGateway,
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

    const criado = await this.psp.criarPix({
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
          psp: this.psp.nome,
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
      psp: this.psp.nome,
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
    return this._view(await this._reconciliar(charge));
  }

  /** Webhook do PSP: casa por pspRef (cross-tenant) e re-consulta o status. */
  async webhook(
    body: unknown,
    query: Record<string, unknown>,
  ): Promise<{ ok: true }> {
    const parsed = this.psp.parseWebhook(body, query);
    if (parsed) {
      await TenantContext.runAsSystem(async () => {
        const charge = await this.prisma.pixCharge.findFirst({
          where: { pspRef: parsed.pspRef },
        });
        if (charge) await this._reconciliar(charge);
      });
    }
    return { ok: true };
  }

  private async _reconciliar(
    charge: Prisma.PixChargeGetPayload<object>,
  ): Promise<Prisma.PixChargeGetPayload<object>> {
    if (charge.status !== 'pending') return charge;
    if (charge.expiresAt && charge.expiresAt < new Date()) {
      return this.prisma.pixCharge.update({
        where: { id: charge.id },
        data: { status: 'expired' },
      });
    }
    if (!charge.pspRef) return charge;
    const st = await this.psp.consultar(charge.pspRef);
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
