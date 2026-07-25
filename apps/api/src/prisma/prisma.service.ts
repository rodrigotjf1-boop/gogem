import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { tenantScopeMiddleware } from './tenant-scope.middleware';

/**
 * PrismaService — cliente Prisma gerenciado pelo ciclo de vida do Nest.
 *
 * Multi-tenant (CLAUDE.md §2): NENHUMA query de modelo escopado roda sem
 * filtro de `tenantId`. O escopo é aplicado pelo middleware `$use`
 * (`tenantScopeMiddleware`), que lê o `TenantContext` (AsyncLocalStorage
 * alimentado pelo TenantContextInterceptor a partir do JWT) e injeta o tenant
 * em toda leitura/escrita, falhando fechado quando não há tenant no contexto.
 */
@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor() {
    super();
    this.$use(tenantScopeMiddleware);
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
