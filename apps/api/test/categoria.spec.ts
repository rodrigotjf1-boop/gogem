import { ConflictException, NotFoundException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CategoriaService } from '../src/categoria/categoria.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    categoria: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    produto: { count: vi.fn() },
  };
  const service = new CategoriaService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('CategoriaService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('list ordena por ordem asc, nome asc — SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findMany.mockResolvedValue([]);
    await service.list();
    expect(prisma.categoria.findMany).toHaveBeenCalledWith({
      orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
    });
    // Prova: o service não injeta tenantId (delega ao middleware).
    const arg = prisma.categoria.findMany.mock.calls[0][0];
    expect(JSON.stringify(arg)).not.toContain('tenantId');
  });

  it('create escreve nome/ordem SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.create.mockResolvedValue({ id: 'c-1' });
    await service.create({ nome: 'Bebidas', ordem: 2 });
    expect(prisma.categoria.create).toHaveBeenCalledWith({
      data: { nome: 'Bebidas', ordem: 2 },
    });
    expect('tenantId' in prisma.categoria.create.mock.calls[0][0].data).toBe(
      false,
    );
  });

  it('create default ordem = 0 quando ausente', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.create.mockResolvedValue({ id: 'c-2' });
    await service.create({ nome: 'Lanches' });
    expect(prisma.categoria.create).toHaveBeenCalledWith({
      data: { nome: 'Lanches', ordem: 0 },
    });
  });

  it('getOne lança NotFound quando não existe (id de outro tenant → null)', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findFirst.mockResolvedValue(null);
    await expect(service.getOne('x')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('update confere existência e escreve SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findFirst.mockResolvedValue({ id: 'c-1' });
    prisma.categoria.update.mockResolvedValue({ id: 'c-1', nome: 'Novo' });
    await service.update('c-1', { nome: 'Novo' });
    expect(prisma.categoria.update).toHaveBeenCalledWith({
      where: { id: 'c-1' },
      data: { nome: 'Novo', ordem: undefined },
    });
    expect('tenantId' in prisma.categoria.update.mock.calls[0][0].where).toBe(
      false,
    );
  });

  it('delete sem produtos remove e devolve id', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findFirst.mockResolvedValue({ id: 'c-1' });
    prisma.produto.count.mockResolvedValue(0);
    prisma.categoria.delete.mockResolvedValue({ id: 'c-1' });
    await expect(service.remove('c-1')).resolves.toEqual({ id: 'c-1' });
    expect(prisma.categoria.delete).toHaveBeenCalledWith({
      where: { id: 'c-1' },
    });
  });

  it('delete-with-produtos lança Conflict (409) e NÃO deleta', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findFirst.mockResolvedValue({ id: 'c-1' });
    prisma.produto.count.mockResolvedValue(3);
    await expect(service.remove('c-1')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.categoria.delete).not.toHaveBeenCalled();
  });
});
