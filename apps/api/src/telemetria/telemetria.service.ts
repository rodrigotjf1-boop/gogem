import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { RegistrarEventoDto } from './dto/registrar-evento.dto';

/** Evento como o Console enxerga (com nomes de dispositivo/loja). */
export interface EventoView {
  id: string;
  nivel: string;
  mensagem: string;
  detalhe: string | null;
  appVersao: string | null;
  createdAt: Date;
  dispositivo: string;
  loja: string;
}

/**
 * TelemetriaService — o totem SOBE eventos (write tenant-scoped pelo contexto do
 * device); o Console da Distribuição LÊ cross-tenant (runAsSystem). `TelemetriaEvento`
 * é tenant-scoped: a escrita injeta o tenantId; a leitura org bypassa o escopo.
 */
@Injectable()
export class TelemetriaService {
  constructor(private readonly prisma: PrismaService) {}

  /** Registra um evento do totem. O tenantId vem do contexto (device-auth). */
  async registrar(
    deviceId: string,
    dto: RegistrarEventoDto,
  ): Promise<{ ok: true }> {
    // tenantId NÃO entra à mão — o middleware injeta do contexto (device-auth).
    const data = {
      dispositivoId: deviceId,
      nivel: dto.nivel ?? 'erro',
      mensagem: dto.mensagem.slice(0, 500),
      detalhe: dto.detalhe?.slice(0, 4000) ?? null,
      appVersao: dto.appVersao ?? null,
    } satisfies Omit<Prisma.TelemetriaEventoUncheckedCreateInput, 'tenantId'>;
    await this.prisma.telemetriaEvento.create({
      data: data as Prisma.TelemetriaEventoUncheckedCreateInput,
    });
    return { ok: true };
  }

  /** Últimos eventos de TODA a frota (org, cross-tenant). */
  async listarOrg(limite = 200): Promise<EventoView[]> {
    return TenantContext.runAsSystem(async () => {
      const eventos = await this.prisma.telemetriaEvento.findMany({
        orderBy: { createdAt: 'desc' },
        take: Math.min(limite, 500),
      });
      const devIds = [...new Set(eventos.map((e) => e.dispositivoId))];
      const tenIds = [...new Set(eventos.map((e) => e.tenantId))];
      const [devs, tens] = await Promise.all([
        this.prisma.dispositivo.findMany({
          where: { id: { in: devIds } },
          select: { id: true, nome: true },
        }),
        this.prisma.tenant.findMany({
          where: { id: { in: tenIds } },
          select: { id: true, nome: true },
        }),
      ]);
      const devMap = new Map(devs.map((d) => [d.id, d.nome]));
      const tenMap = new Map(tens.map((t) => [t.id, t.nome]));
      return eventos.map((e) => ({
        id: e.id,
        nivel: e.nivel,
        mensagem: e.mensagem,
        detalhe: e.detalhe,
        appVersao: e.appVersao,
        createdAt: e.createdAt,
        dispositivo: devMap.get(e.dispositivoId) ?? e.dispositivoId,
        loja: tenMap.get(e.tenantId) ?? e.tenantId,
      }));
    });
  }
}
