import { BadRequestException, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CreateProdutoDto } from '../src/produto/dto/create-produto.dto';
import { SetExternalRefsDto } from '../src/produto/dto/set-external-refs.dto';
import { ProdutoService } from '../src/produto/produto.service';
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
    categoria: { findFirst: vi.fn() },
  };
  const service = new ProdutoService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('ProdutoService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('list aplica filtros categoriaId/disponivel e ordena por nome', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findMany.mockResolvedValue([]);
    await service.list({ categoriaId: 'c-1', disponivel: true });
    expect(prisma.produto.findMany).toHaveBeenCalledWith({
      where: { categoriaId: 'c-1', disponivel: true },
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
      where: {},
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
