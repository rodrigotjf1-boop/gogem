import { BadRequestException, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CreateProdutoDto } from '../src/produto/dto/create-produto.dto';
import { SetExternalRefsDto } from '../src/produto/dto/set-external-refs.dto';
import { ProdutoService } from '../src/produto/produto.service';
import type { CardapioService } from '../src/cardapio/cardapio.service';
import type { RegemPauseClient } from '../src/integracoes/regem/regem-pause.client';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    produto: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    produtoUpsell: {
      findMany: vi.fn(),
      deleteMany: vi.fn(),
      create: vi.fn(),
    },
    categoria: { findFirst: vi.fn() },
    $transaction: vi.fn().mockResolvedValue([]),
  };
  const cardapios = { resolverAlvo: vi.fn().mockResolvedValue('card-1') };
  const regemPause = { pausar: vi.fn().mockResolvedValue(true) };
  const service = new ProdutoService(
    prisma as unknown as PrismaService,
    cardapios as unknown as CardapioService,
    regemPause as unknown as RegemPauseClient,
  );
  return { service, prisma, cardapios, regemPause };
}

describe('ProdutoService — upsells (F2)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('setUpsells deduplica, exclui o próprio produto e grava na ordem', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p1' }); // getOne
    // valida existência dos sugeridos (tenant-scoped): B e C existem
    prisma.produto.findMany.mockResolvedValue([{ id: 'B' }, { id: 'C' }]);

    const r = await service.setUpsells('p1', ['B', 'C', 'B', 'p1']);

    expect(r).toEqual({ total: 2 });
    // replace-all: apaga os antigos primeiro
    expect(prisma.produtoUpsell.deleteMany).toHaveBeenCalledWith({
      where: { produtoId: 'p1' },
    });
    // cria B (ordem 0) e C (ordem 1); 'p1' (si mesmo) foi excluído
    const criados = prisma.produtoUpsell.create.mock.calls.map(
      (c) => c[0].data,
    );
    expect(criados).toEqual([
      { produtoId: 'p1', sugeridoId: 'B', ordem: 0 },
      { produtoId: 'p1', sugeridoId: 'C', ordem: 1 },
    ]);
  });

  it('setUpsells rejeita sugerido inexistente no tenant', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p1' });
    prisma.produto.findMany.mockResolvedValue([{ id: 'B' }]); // C não existe
    await expect(service.setUpsells('p1', ['B', 'C'])).rejects.toThrow(
      BadRequestException,
    );
    expect(prisma.produtoUpsell.create).not.toHaveBeenCalled();
  });

  it('listUpsells resolve nome/preço do sugerido, ordenado', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p1' });
    prisma.produtoUpsell.findMany.mockResolvedValue([
      {
        id: 'u1',
        sugeridoId: 'B',
        ordem: 0,
        sugerido: { nome: 'Refri', precoCentavos: 800, imagemUrl: null },
      },
    ]);
    const out = await service.listUpsells('p1');
    expect(out[0]).toEqual({
      id: 'u1',
      sugeridoId: 'B',
      nome: 'Refri',
      precoCentavos: 800,
      imagemUrl: null,
      ordem: 0,
    });
  });
});

describe('ProdutoService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('list aplica filtros categoriaId/disponivel e ordena por nome', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findMany.mockResolvedValue([]);
    await service.list({ categoriaId: 'c-1', disponivel: true });
    expect(prisma.produto.findMany).toHaveBeenCalledWith({
      where: { cardapioId: 'card-1', categoriaId: 'c-1', disponivel: true },
      orderBy: { nome: 'asc' },
    });
    // SEM tenantId manual (delegado ao middleware).
    expect(
      JSON.stringify(prisma.produto.findMany.mock.calls[0][0]),
    ).not.toContain('tenantId');
  });

  it('list sem filtros usa where vazio', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findMany.mockResolvedValue([]);
    await service.list({});
    expect(prisma.produto.findMany).toHaveBeenCalledWith({
      where: { cardapioId: 'card-1' },
      orderBy: { nome: 'asc' },
    });
  });

  it('getOne lança NotFound em id ausente/outro tenant', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue(null);
    await expect(service.getOne('x')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('create valida categoriaId: inexistente → BadRequest, não cria', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findFirst.mockResolvedValue(null);
    await expect(
      service.create({ nome: 'X', precoCentavos: 100, categoriaId: 'c-x' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.produto.create).not.toHaveBeenCalled();
  });

  it('create com categoria válida escreve preço em centavos, SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findFirst.mockResolvedValue({ id: 'c-1' });
    prisma.produto.create.mockResolvedValue({ id: 'p-1' });
    await service.create({
      nome: 'X-Salada',
      precoCentavos: 2590,
      categoriaId: 'c-1',
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'PROD-1' }],
    });
    const data = prisma.produto.create.mock.calls[0][0].data;
    expect(data.precoCentavos).toBe(2590);
    expect(data.disponivel).toBe(true);
    expect(data.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: 'PROD-1' },
    ]);
    expect('tenantId' in data).toBe(false);
  });

  it('pausar: disponivel=false local + propaga ao Regem (tem código)', async () => {
    const { service, prisma, regemPause } = makeService();
    prisma.produto.findFirst.mockResolvedValue({
      id: 'p-1',
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'PROD-1' }],
    });
    prisma.produto.update.mockResolvedValue({ id: 'p-1', disponivel: false });

    const res = await service.pausar('p-1', true);

    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'p-1' },
      data: { disponivel: false },
    });
    expect(regemPause.pausar).toHaveBeenCalledWith('PROD-1', true);
    expect(res.propagadoRegem).toBe(true);
  });

  it('pausar sem código Regem: não propaga (só local)', async () => {
    const { service, prisma, regemPause } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p-2', externalRefs: [] });
    prisma.produto.update.mockResolvedValue({ id: 'p-2', disponivel: true });

    const res = await service.pausar('p-2', false);

    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'p-2' },
      data: { disponivel: true },
    });
    expect(regemPause.pausar).not.toHaveBeenCalled();
    expect(res.propagadoRegem).toBe(false);
  });

  it('setExternalRefs confere existência e persiste refs normalizados', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p-1' });
    prisma.produto.update.mockResolvedValue({ id: 'p-1' });
    await service.setExternalRefs('p-1', [
      { sistema: 'regem', codigo_pdv: 'A', loja: 'centro' },
    ]);
    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'p-1' },
      data: {
        externalRefs: [{ sistema: 'regem', codigo_pdv: 'A', loja: 'centro' }],
      },
    });
  });

  it('remove confere existência e deleta', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p-1' });
    prisma.produto.delete.mockResolvedValue({ id: 'p-1' });
    await expect(service.remove('p-1')).resolves.toEqual({ id: 'p-1' });
  });
});

describe('externalRefs — validação no DTO (class-validator)', () => {
  it('aceita array de refs bem-formados', async () => {
    const dto = plainToInstance(CreateProdutoDto, {
      nome: 'X',
      precoCentavos: 100,
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'P1', loja: 'centro' }],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('rejeita ref sem codigo_pdv (shape inválido)', async () => {
    const dto = plainToInstance(CreateProdutoDto, {
      nome: 'X',
      precoCentavos: 100,
      externalRefs: [{ sistema: 'regem' }],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejeita ref com tipos errados (codigo_pdv numérico)', async () => {
    const dto = plainToInstance(SetExternalRefsDto, {
      externalRefs: [{ sistema: 'regem', codigo_pdv: 123 }],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejeita quando externalRefs não é array', async () => {
    const dto = plainToInstance(SetExternalRefsDto, {
      externalRefs: { sistema: 'regem', codigo_pdv: 'x' },
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});
