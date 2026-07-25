import { ForbiddenException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { tenantScopeMiddleware } from '../src/prisma/tenant-scope.middleware';
import { TenantContext } from '../src/tenant/tenant-context';

const TENANT = 'tenant-1';

/** Executa o middleware dentro de um contexto de tenant e devolve os params. */
async function comTenant(params: Prisma.MiddlewareParams): Promise<{
  params: Prisma.MiddlewareParams;
  next: ReturnType<typeof vi.fn>;
}> {
  const next = vi.fn().mockResolvedValue('ok');
  await TenantContext.run({ tenantId: TENANT }, () =>
    tenantScopeMiddleware(params, next),
  );
  // next recebe o mesmo objeto params (mutado in place).
  return { params: next.mock.calls[0][0], next };
}

describe('tenantScopeMiddleware', () => {
  beforeEach(() => vi.clearAllMocks());

  it('reads (findMany) injetam tenantId no where', async () => {
    const { params } = await comTenant({
      model: 'Produto',
      action: 'findMany',
      args: { where: { disponivel: true } },
    } as Prisma.MiddlewareParams);
    expect(params.args.where).toEqual({ disponivel: true, tenantId: TENANT });
  });

  it('count/aggregate/groupBy injetam tenantId no where', async () => {
    for (const action of ['count', 'aggregate', 'groupBy'] as const) {
      const { params } = await comTenant({
        model: 'Categoria',
        action,
        args: {},
      } as Prisma.MiddlewareParams);
      expect(params.args.where).toEqual({ tenantId: TENANT });
    }
  });

  it('findUnique é convertido para findFirst com tenantId no where', async () => {
    const { params } = await comTenant({
      model: 'Usuario',
      action: 'findUnique',
      args: { where: { id: 'u-1' } },
    } as Prisma.MiddlewareParams);
    expect(params.action).toBe('findFirst');
    expect(params.args.where).toEqual({ id: 'u-1', tenantId: TENANT });
  });

  it('findUniqueOrThrow vira findFirstOrThrow com tenantId', async () => {
    const { params } = await comTenant({
      model: 'Usuario',
      action: 'findUniqueOrThrow',
      args: { where: { id: 'u-1' } },
    } as Prisma.MiddlewareParams);
    expect(params.action).toBe('findFirstOrThrow');
    expect(params.args.where).toEqual({ id: 'u-1', tenantId: TENANT });
  });

  it('create injeta tenantId no data', async () => {
    const { params } = await comTenant({
      model: 'Produto',
      action: 'create',
      args: { data: { nome: 'X' } },
    } as Prisma.MiddlewareParams);
    expect(params.args.data).toEqual({ nome: 'X', tenantId: TENANT });
  });

  it('createMany injeta tenantId em cada item do array', async () => {
    const { params } = await comTenant({
      model: 'Produto',
      action: 'createMany',
      args: { data: [{ nome: 'A' }, { nome: 'B' }] },
    } as Prisma.MiddlewareParams);
    expect(params.args.data).toEqual([
      { nome: 'A', tenantId: TENANT },
      { nome: 'B', tenantId: TENANT },
    ]);
  });

  it('update/delete garantem tenantId no where', async () => {
    for (const action of [
      'update',
      'updateMany',
      'delete',
      'deleteMany',
    ] as const) {
      const { params } = await comTenant({
        model: 'Produto',
        action,
        args: { where: { id: 'p-1' } },
      } as Prisma.MiddlewareParams);
      expect(params.args.where).toEqual({ id: 'p-1', tenantId: TENANT });
    }
  });

  it('upsert injeta tenantId no where e no create', async () => {
    const { params } = await comTenant({
      model: 'MenuVersion',
      action: 'upsert',
      args: {
        where: { id: 'm-1' },
        create: { versao: 1 },
        update: { versao: 2 },
      },
    } as Prisma.MiddlewareParams);
    expect(params.args.where).toEqual({ id: 'm-1', tenantId: TENANT });
    expect(params.args.create).toEqual({ versao: 1, tenantId: TENANT });
  });

  it('é robusto a args indefinido', async () => {
    const { params } = await comTenant({
      model: 'Unidade',
      action: 'findMany',
    } as Prisma.MiddlewareParams);
    expect(params.args.where).toEqual({ tenantId: TENANT });
  });

  it('modelo NÃO escopado (Tenant) passa sem injeção e sem tenant', async () => {
    const next = vi.fn().mockResolvedValue('ok');
    const params = {
      model: 'Tenant',
      action: 'findMany',
      args: {},
    } as Prisma.MiddlewareParams;
    await expect(tenantScopeMiddleware(params, next)).resolves.toBe('ok');
    expect(params.args).toEqual({});
  });

  it('FAIL-CLOSED: read de modelo escopado sem tenant lança Forbidden', () => {
    const next = vi.fn();
    expect(() =>
      tenantScopeMiddleware(
        {
          model: 'Produto',
          action: 'findMany',
          args: {},
        } as Prisma.MiddlewareParams,
        next,
      ),
    ).toThrow(ForbiddenException);
    expect(next).not.toHaveBeenCalled();
  });

  it('escape hatch (runAsSystem) permite create sem tenant no contexto', async () => {
    const next = vi.fn().mockResolvedValue('ok');
    const params = {
      model: 'Usuario',
      action: 'create',
      args: { data: { tenantId: 'explicit', nome: 'Z' } },
    } as Prisma.MiddlewareParams;
    await TenantContext.runAsSystem(() => tenantScopeMiddleware(params, next));
    // Sem injeção automática: o chamador forneceu o tenantId à mão.
    expect(params.args.data).toEqual({ tenantId: 'explicit', nome: 'Z' });
    expect(next).toHaveBeenCalledOnce();
  });
});
