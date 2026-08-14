import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';

/** Uma ação sensível a registrar na trilha. */
export interface EventoAuditoria {
  /** Verbo.recurso, ex.: 'pedido.cancelar', 'integracao.salvar'. */
  acao: string;
  recurso?: string;
  recursoId?: string;
  detalhe?: Record<string, unknown>;
}

/**
 * AuditoriaService — trilha append-only das ações sensíveis (Fase 5 do plano de
 * segurança). Lê o ator (usuário/papel) e o tenant do `TenantContext` — nada é
 * passado pelo cliente. Tenant-scoped: o middleware do Prisma injeta o tenantId,
 * então cada empresa só enxerga a própria trilha. É BEST-EFFORT: uma falha ao
 * auditar NUNCA derruba a ação auditada.
 */
@Injectable()
export class AuditoriaService {
  constructor(private readonly prisma: PrismaService) {}

  async registrar(e: EventoAuditoria): Promise<void> {
    try {
      const ctx = TenantContext.get();
      if (!ctx) return; // fora de um contexto de tenant (bootstrap) → não audita
      const base = {
        usuarioId: ctx.userId ?? null,
        papel: ctx.papel ?? null,
        acao: e.acao,
        recurso: e.recurso ?? null,
        recursoId: e.recursoId ?? null,
      } satisfies Omit<
        Prisma.AuditoriaUncheckedCreateInput,
        'tenantId' | 'detalhe'
      >;
      await this.prisma.auditoria.create({
        data: {
          ...base,
          ...(e.detalhe ? { detalhe: e.detalhe as Prisma.InputJsonValue } : {}),
        } as Prisma.AuditoriaUncheckedCreateInput,
      });
    } catch {
      /* best-effort: auditoria não pode derrubar a ação auditada */
    }
  }

  /** Trilha do tenant, mais recente primeiro (presidente). */
  async listar(limite = 200) {
    return this.prisma.auditoria.findMany({
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limite, 1), 1000),
    });
  }
}
