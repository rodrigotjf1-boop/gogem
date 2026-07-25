import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/**
 * PrismaService — cliente Prisma gerenciado pelo ciclo de vida do Nest.
 *
 * Multi-tenant (CLAUDE.md §2): NENHUMA query pode rodar sem filtro de
 * `tenantId`. O escopo é aplicado por um middleware ($use) — abaixo há um
 * STUB documentado que mostra onde e como o tenant será injetado.
 */
@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super();
    this.registerTenantScopeMiddleware();
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  /**
   * STUB de escopo por tenant.
   *
   * Modelos de negócio que carregam `tenantId` — o filtro deve ser injetado
   * automaticamente em toda operação de leitura/escrita.
   *
   * TODO(S1–S2): obter o `tenantId` do contexto da requisição
   *   (AsyncLocalStorage alimentado por um middleware/guard de auth a partir
   *   do JWT ou do X-Sync-Token do dispositivo) e aplicá-lo aqui:
   *     - reads  (findMany/findFirst/count/aggregate): injetar em `args.where`.
   *     - writes (create/createMany): injetar em `args.data`.
   *     - update/delete: garantir `tenantId` no `where` (nunca vazar entre
   *       tenants). Falhar fechado se o contexto não tiver tenant.
   *
   * Enquanto o contexto não existe, este middleware apenas registra a
   * intenção e repassa a chamada — NÃO confiar nele para isolamento ainda.
   */
  private registerTenantScopeMiddleware(): void {
    const TENANT_SCOPED_MODELS = new Set([
      'Unidade',
      'Usuario',
      'Categoria',
      'Produto',
      'MenuVersion',
    ]);

    this.$use(async (params, next) => {
      if (params.model && TENANT_SCOPED_MODELS.has(params.model)) {
        // TODO(S1–S2): const tenantId = tenantContext.get();
        //              if (!tenantId) throw new ForbiddenException('sem tenant');
        //              injetar tenantId em params.args.where / params.args.data.
        this.logger.debug(
          `tenant-scope (stub): ${params.model}.${params.action} — ` +
            `TODO injetar tenantId do contexto da requisição`,
        );
      }
      return next(params);
    });
  }
}
