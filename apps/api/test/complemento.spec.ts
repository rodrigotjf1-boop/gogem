import { BadRequestException, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ComplementoService } from '../src/complemento/complemento.service';
import { CreateOpcaoDto } from '../src/complemento/dto/create-opcao.dto';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    produto: { findFirst: vi.fn() },
    complementoGrupo: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    complementoOpcao: {
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
      deleteMany: vi.fn(),
    },
  };
  const service = new ComplementoService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('ComplementoService — grupos', () => {
  beforeEach(() => vi.clearAllMocks());

  it('listGrupos valida produto e inclui opções ordenadas, SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p-1' });
    prisma.complementoGrupo.findMany.mockResolvedValue([]);
    await service.listGrupos('p-1');
    expect(prisma.complementoGrupo.findMany).toHaveBeenCalledWith({
      where: { produtoId: 'p-1' },
      orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
      include: { opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] } },
    });
    expect(
      JSON.stringify(prisma.complementoGrupo.findMany.mock.calls[0][0]),
    ).not.toContain('tenantId');
  });

  it('listGrupos com produto inexistente → BadRequest', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue(null);
    await expect(service.listGrupos('p-x')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('createGrupo valida produto: inexistente → BadRequest, não cria', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue(null);
    await expect(
      service.createGrupo('p-x', { nome: 'Bebida' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.complementoGrupo.create).not.toHaveBeenCalled();
  });

  it('createGrupo com produto válido cria SEM tenantId manual, max nulo default', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p-1' });
    prisma.complementoGrupo.create.mockResolvedValue({ id: 'g-1' });
    await service.createGrupo('p-1', {
      nome: 'Escolha a bebida',
      min: 1,
      obrigatorio: true,
    });
    const data = prisma.complementoGrupo.create.mock.calls[0][0].data;
    expect(data.produtoId).toBe('p-1');
    expect(data.min).toBe(1);
    expect(data.max).toBeNull();
    expect(data.obrigatorio).toBe(true);
    expect('tenantId' in data).toBe(false);
  });

  it('createGrupo rejeita min/max incoerente (max < min) → BadRequest', async () => {
    const { service, prisma } = makeService();
    prisma.produto.findFirst.mockResolvedValue({ id: 'p-1' });
    await expect(
      service.createGrupo('p-1', { nome: 'X', min: 3, max: 1 }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.complementoGrupo.create).not.toHaveBeenCalled();
  });

  it('updateGrupo revalida min/max mesclando com o atual → BadRequest', async () => {
    const { service, prisma } = makeService();
    prisma.complementoGrupo.findFirst.mockResolvedValue({
      id: 'g-1',
      min: 1,
      max: 2,
    });
    // Sobe o min para 5 mantendo max=2 (atual) → incoerente.
    await expect(service.updateGrupo('g-1', { min: 5 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.complementoGrupo.update).not.toHaveBeenCalled();
  });

  it('updateGrupo 404 quando grupo não existe', async () => {
    const { service, prisma } = makeService();
    prisma.complementoGrupo.findFirst.mockResolvedValue(null);
    await expect(
      service.updateGrupo('g-x', { nome: 'Y' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('removeGrupo cascateia opções: deleteMany das opções ANTES do delete do grupo', async () => {
    const { service, prisma } = makeService();
    prisma.complementoGrupo.findFirst.mockResolvedValue({ id: 'g-1' });
    prisma.complementoOpcao.deleteMany.mockResolvedValue({ count: 2 });
    prisma.complementoGrupo.delete.mockResolvedValue({ id: 'g-1' });
    const order: string[] = [];
    prisma.complementoOpcao.deleteMany.mockImplementation(async () => {
      order.push('opcoes');
      return { count: 2 };
    });
    prisma.complementoGrupo.delete.mockImplementation(async () => {
      order.push('grupo');
      return { id: 'g-1' };
    });
    await expect(service.removeGrupo('g-1')).resolves.toEqual({ id: 'g-1' });
    expect(prisma.complementoOpcao.deleteMany).toHaveBeenCalledWith({
      where: { grupoId: 'g-1' },
    });
    expect(order).toEqual(['opcoes', 'grupo']);
  });
});

describe('ComplementoService — opções', () => {
  beforeEach(() => vi.clearAllMocks());

  it('createOpcao valida grupo: inexistente → NotFound, não cria', async () => {
    const { service, prisma } = makeService();
    prisma.complementoGrupo.findFirst.mockResolvedValue(null);
    await expect(
      service.createOpcao('g-x', { nome: 'Coca' }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.complementoOpcao.create).not.toHaveBeenCalled();
  });

  it('createOpcao com grupo válido escreve delta em centavos, refs normalizados, SEM tenantId', async () => {
    const { service, prisma } = makeService();
    prisma.complementoGrupo.findFirst.mockResolvedValue({ id: 'g-1' });
    prisma.complementoOpcao.create.mockResolvedValue({ id: 'o-1' });
    await service.createOpcao('g-1', {
      nome: 'Coca-Cola',
      precoCentavosDelta: 500,
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'OPC-1', loja: 'centro' }],
    });
    const data = prisma.complementoOpcao.create.mock.calls[0][0].data;
    expect(data.grupoId).toBe('g-1');
    expect(data.precoCentavosDelta).toBe(500);
    expect(data.disponivel).toBe(true);
    expect(data.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: 'OPC-1', loja: 'centro' },
    ]);
    expect('tenantId' in data).toBe(false);
  });

  it('createOpcao sem refs persiste array vazio (opção informativa)', async () => {
    const { service, prisma } = makeService();
    prisma.complementoGrupo.findFirst.mockResolvedValue({ id: 'g-1' });
    prisma.complementoOpcao.create.mockResolvedValue({ id: 'o-1' });
    await service.createOpcao('g-1', { nome: 'Sem açúcar' });
    const data = prisma.complementoOpcao.create.mock.calls[0][0].data;
    expect(data.externalRefs).toEqual([]);
    expect(data.precoCentavosDelta).toBe(0);
  });

  it('removeOpcao confere existência e deleta', async () => {
    const { service, prisma } = makeService();
    prisma.complementoOpcao.findFirst.mockResolvedValue({ id: 'o-1' });
    prisma.complementoOpcao.delete.mockResolvedValue({ id: 'o-1' });
    await expect(service.removeOpcao('o-1')).resolves.toEqual({ id: 'o-1' });
  });
});

describe('opção externalRefs — validação no DTO (class-validator)', () => {
  it('aceita opção com refs bem-formados', async () => {
    const dto = plainToInstance(CreateOpcaoDto, {
      nome: 'Coca',
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'O1', loja: 'centro' }],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('rejeita ref sem codigo_pdv (shape inválido)', async () => {
    const dto = plainToInstance(CreateOpcaoDto, {
      nome: 'Coca',
      externalRefs: [{ sistema: 'regem' }],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejeita externalRefs que não é array', async () => {
    const dto = plainToInstance(CreateOpcaoDto, {
      nome: 'Coca',
      externalRefs: { sistema: 'regem', codigo_pdv: 'x' },
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});
