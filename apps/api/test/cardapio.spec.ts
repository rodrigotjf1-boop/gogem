import { BadRequestException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CardapioService } from '../src/cardapio/cardapio.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    cardapio: {
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
      delete: vi.fn(),
    },
    categoria: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn(),
      deleteMany: vi.fn(),
    },
    produto: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn(),
      deleteMany: vi.fn(),
    },
    complementoGrupo: { create: vi.fn(), deleteMany: vi.fn() },
    complementoOpcao: { create: vi.fn(), deleteMany: vi.fn() },
  };
  const service = new CardapioService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('CardapioService.ativoId — garante padrão', () => {
  beforeEach(() => vi.clearAllMocks());

  it('devolve o ativo existente', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValueOnce({ id: 'c-ativo' });
    await expect(service.ativoId()).resolves.toBe('c-ativo');
    expect(prisma.cardapio.create).not.toHaveBeenCalled();
  });

  it('sem ativo mas com algum → ativa o primeiro', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst
      .mockResolvedValueOnce(null) // nenhum ativo
      .mockResolvedValueOnce({ id: 'c-1' }); // primeiro por ordem
    prisma.cardapio.update.mockResolvedValue({});
    await expect(service.ativoId()).resolves.toBe('c-1');
    expect(prisma.cardapio.update).toHaveBeenCalledWith({
      where: { id: 'c-1' },
      data: { ativo: true },
    });
  });

  it('nenhum cardápio → cria "Cardápio padrão" ativo', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValue(null);
    prisma.cardapio.create.mockResolvedValue({ id: 'novo' });
    await expect(service.ativoId()).resolves.toBe('novo');
    const data = prisma.cardapio.create.mock.calls[0][0].data;
    expect(data.ativo).toBe(true);
    expect(JSON.stringify(data)).not.toContain('tenantId');
  });
});

describe('CardapioService.create — limite e modo', () => {
  beforeEach(() => vi.clearAllMocks());

  it('bloqueia o 3º cardápio (máx 2)', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.count.mockResolvedValue(2);
    await expect(service.create({ nome: 'Terceiro' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.cardapio.create).not.toHaveBeenCalled();
  });

  it('cria inativo (vazio)', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.count.mockResolvedValue(1);
    prisma.cardapio.create.mockResolvedValue({ id: 'c-2' });
    prisma.cardapio.findFirst.mockResolvedValue({
      id: 'c-2',
      nome: 'Novo',
      ativo: false,
      ordem: 1,
      _count: { produtos: 0 },
    });
    const view = await service.create({ nome: 'Novo', modo: 'vazio' });
    expect(prisma.cardapio.create.mock.calls[0][0].data.ativo).toBe(false);
    expect(view.ativo).toBe(false);
  });
});

describe('CardapioService.ativar — exclusivo', () => {
  beforeEach(() => vi.clearAllMocks());

  it('desativa os demais e ativa o alvo', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst
      .mockResolvedValueOnce({ id: 'c-2', ativo: false }) // assertExiste
      .mockResolvedValueOnce({
        id: 'c-2',
        nome: 'B',
        ativo: true,
        ordem: 1,
        _count: { produtos: 3 },
      });
    prisma.cardapio.updateMany.mockResolvedValue({});
    prisma.cardapio.update.mockResolvedValue({});
    const view = await service.ativar('c-2');
    expect(prisma.cardapio.updateMany).toHaveBeenCalledWith({
      where: { ativo: true },
      data: { ativo: false },
    });
    expect(prisma.cardapio.update).toHaveBeenCalledWith({
      where: { id: 'c-2' },
      data: { ativo: true },
    });
    expect(view.ativo).toBe(true);
  });
});

describe('CardapioService.remove — guardas', () => {
  beforeEach(() => vi.clearAllMocks());

  it('não exclui o ativo', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValue({ id: 'c-1', ativo: true });
    await expect(service.remove('c-1')).rejects.toThrow(/ativo/);
    expect(prisma.cardapio.delete).not.toHaveBeenCalled();
  });

  it('não exclui o último', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValue({ id: 'c-1', ativo: false });
    prisma.cardapio.count.mockResolvedValue(1);
    await expect(service.remove('c-1')).rejects.toThrow(/ao menos um/);
    expect(prisma.cardapio.delete).not.toHaveBeenCalled();
  });

  it('exclui um inativo (apaga conteúdo antes)', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValue({ id: 'c-2', ativo: false });
    prisma.cardapio.count.mockResolvedValue(2);
    prisma.cardapio.delete.mockResolvedValue({});
    await expect(service.remove('c-2')).resolves.toEqual({ id: 'c-2' });
    expect(prisma.produto.deleteMany).toHaveBeenCalledWith({
      where: { cardapioId: 'c-2' },
    });
    expect(prisma.categoria.deleteMany).toHaveBeenCalledWith({
      where: { cardapioId: 'c-2' },
    });
  });
});

describe('CardapioService.resolverAlvo', () => {
  beforeEach(() => vi.clearAllMocks());

  it('id informado válido → ele mesmo', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValue({ id: 'c-2' });
    await expect(service.resolverAlvo('c-2')).resolves.toBe('c-2');
  });

  it('sem id → cai no ativo', async () => {
    const { service, prisma } = makeService();
    prisma.cardapio.findFirst.mockResolvedValue({ id: 'c-ativo' });
    await expect(service.resolverAlvo()).resolves.toBe('c-ativo');
  });
});
