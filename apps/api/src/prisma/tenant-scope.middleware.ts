import { ForbiddenException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../tenant/tenant-context';

/**
 * Modelos de negócio escopados por tenant (CLAUDE.md §2). `Tenant` NÃO entra —
 * é a raiz do multi-tenant.
 */
export const TENANT_SCOPED_MODELS = new Set([
  'Unidade',
  'Usuario',
  'Categoria',
  'Produto',
  'MenuVersion',
  'ComplementoGrupo',
  'ComplementoOpcao',
  'ProdutoComplemento',
  'ProdutoUpsell',
  'Dispositivo',
  'Pedido',
  'Integracao',
  'Cardapio',
  'Aparencia',
  'OpenDeliveryApp',
  'OpenDeliveryOrder',
  'OpenDeliveryEvent',
  'PixCharge',
  'PointPayment',
]);

/**
 * Middleware de escopo por tenant do Prisma (fail-closed).
 *
 * Injeta `tenantId` (do TenantContext) em toda leitura/escrita dos modelos
 * escopados. Regras:
 *   - reads (findMany/findFirst/count/aggregate/groupBy): where += tenantId.
 *   - findUnique/findUniqueOrThrow: convertidos para findFirst/findFirstOrThrow
 *     (o Prisma proíbe campos não-únicos no `where` de findUnique) e where += tenantId.
 *   - create: data += tenantId. createMany: injeta em cada item (ou no objeto).
 *   - update/updateMany/delete/deleteMany: where += tenantId.
 *   - upsert: where += tenantId e create += tenantId.
 *   - SEM tenant no contexto → lança ForbiddenException, EXCETO em operação de
 *     sistema (TenantContext.runAsSystem — bootstrap de register/login), onde o
 *     chamador fornece o tenantId à mão nos dados.
 *
 * Extraído como função pura para ser testável sem banco (ver test/).
 */
export function tenantScopeMiddleware(
  params: Prisma.MiddlewareParams,
  next: (params: Prisma.MiddlewareParams) => Promise<unknown>,
): Promise<unknown> {
  if (!params.model || !TENANT_SCOPED_MODELS.has(params.model)) {
    return next(params);
  }

  // Escape hatch de sistema: bootstrap fornece o tenantId explicitamente.
  if (TenantContext.isSystem()) {
    return next(params);
  }

  const tenantId = TenantContext.getTenantId();
  if (!tenantId) {
    // Fail-closed: nunca deixar uma query de modelo escopado rodar sem tenant.
    throw new ForbiddenException(
      `Operação ${params.model}.${params.action} sem tenant no contexto`,
    );
  }

  // Robusto a args indefinido.
  const args = (params.args ?? {}) as Record<string, unknown>;
  params.args = args;

  switch (params.action) {
    case 'findUnique':
    case 'findUniqueOrThrow': {
      // Converter para findFirst: o where de findUnique não aceita `tenantId`.
      params.action =
        params.action === 'findUnique' ? 'findFirst' : 'findFirstOrThrow';
      args.where = mergeTenant(args.where, tenantId);
      break;
    }
    case 'findFirst':
    case 'findFirstOrThrow':
    case 'findMany':
    case 'count':
    case 'aggregate':
    case 'groupBy': {
      args.where = mergeTenant(args.where, tenantId);
      break;
    }
    case 'create': {
      args.data = mergeTenant(args.data, tenantId);
      break;
    }
    case 'createMany': {
      const data = args.data;
      args.data = Array.isArray(data)
        ? data.map((item) => mergeTenant(item, tenantId))
        : mergeTenant(data, tenantId);
      break;
    }
    case 'update':
    case 'updateMany':
    case 'delete':
    case 'deleteMany': {
      args.where = mergeTenant(args.where, tenantId);
      break;
    }
    case 'upsert': {
      args.where = mergeTenant(args.where, tenantId);
      args.create = mergeTenant(args.create, tenantId);
      break;
    }
    default:
      break;
  }

  return next(params);
}

/** Mescla `tenantId` num objeto de where/data, preservando o que já existe. */
function mergeTenant(
  target: unknown,
  tenantId: string,
): Record<string, unknown> {
  return {
    ...((target as Record<string, unknown> | undefined) ?? {}),
    tenantId,
  };
}
