import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AuditoriaService } from '../src/auditoria/auditoria.service';
import { TenantContext } from '../src/tenant/tenant-context';
import type { PrismaService } from '../src/prisma/prisma.service';

function make() {
  const prisma = { auditoria: { create: vi.fn(), findMany: vi.fn() } };
  const service = new AuditoriaService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('AuditoriaService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('registra com o ator (usuário/papel) lido do TenantContext', async () => {
    const { service, prisma } = make();
    await TenantContext.run(
      { tenantId: 't1', userId: 'u1', papel: 'gerente' },
      async () => {
        await service.registrar({
          acao: 'pedido.cancelar',
          recurso: 'pedido',
          recursoId: 'p9',
          detalhe: { motivo: 'x' },
        });
      },
    );
    expect(prisma.auditoria.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        usuarioId: 'u1',
        papel: 'gerente',
        acao: 'pedido.cancelar',
        recurso: 'pedido',
        recursoId: 'p9',
        detalhe: { motivo: 'x' },
      }),
    });
  });

  it('fora de contexto de tenant: NÃO audita (não cria)', async () => {
    const { service, prisma } = make();
    await service.registrar({ acao: 'x' });
    expect(prisma.auditoria.create).not.toHaveBeenCalled();
  });

  it('best-effort: falha ao gravar NÃO propaga', async () => {
    const { service, prisma } = make();
    prisma.auditoria.create.mockRejectedValue(new Error('db down'));
    await TenantContext.run({ tenantId: 't1' }, async () => {
      await expect(service.registrar({ acao: 'x' })).resolves.toBeUndefined();
    });
  });

  it('listar: mais recente primeiro, com teto', async () => {
    const { service, prisma } = make();
    prisma.auditoria.findMany.mockResolvedValue([]);
    await service.listar(99999);
    expect(prisma.auditoria.findMany).toHaveBeenCalledWith({
      orderBy: { createdAt: 'desc' },
      take: 1000,
    });
  });
});
