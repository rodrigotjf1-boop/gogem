import { BadRequestException, NotFoundException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DispositivoService } from '../src/dispositivo/dispositivo.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    dispositivo: {
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
  };
  const service = new DispositivoService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('DispositivoService.create', () => {
  beforeEach(() => vi.clearAllMocks());

  it('gera código de 6 dígitos + expiração ~15min e cria SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    // Echo do que o service manda no `data` (o service lê o resultado).
    prisma.dispositivo.create.mockImplementation(
      async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'd-1',
        nome: data.nome,
        codigoPareamento: data.codigoPareamento,
        codigoExpiraEm: data.codigoExpiraEm,
      }),
    );

    const antes = Date.now();
    const res = await service.create({ nome: 'Totem entrada' });
    const depois = Date.now();

    // Código de exatamente 6 dígitos.
    expect(res.codigoPareamento).toMatch(/^\d{6}$/);
    // Expira em ~15 min à frente.
    const ttl = res.codigoExpiraEm.getTime() - antes;
    expect(ttl).toBeGreaterThanOrEqual(15 * 60 * 1000 - 1000);
    expect(res.codigoExpiraEm.getTime()).toBeLessThanOrEqual(
      depois + 15 * 60 * 1000,
    );

    // Prova: o service NÃO injeta tenantId (delega ao middleware §2).
    const arg = prisma.dispositivo.create.mock.calls[0][0];
    expect('tenantId' in arg.data).toBe(false);
    expect(JSON.stringify(arg)).not.toContain('tenantId');
    // Nasce não pareado com o tipo default.
    expect(arg.data.pareado).toBe(false);
    expect(arg.data.tipo).toBe('totem');
  });

  it('respeita tipo/unidadeId informados', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.create.mockImplementation(
      async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'd-2',
        nome: data.nome,
        codigoPareamento: data.codigoPareamento,
        codigoExpiraEm: data.codigoExpiraEm,
      }),
    );
    await service.create({ nome: 'PDV', tipo: 'pdv', unidadeId: 'u-9' });
    const data = prisma.dispositivo.create.mock.calls[0][0].data;
    expect(data.tipo).toBe('pdv');
    expect(data.unidadeId).toBe('u-9');
  });
});

describe('DispositivoService.list', () => {
  beforeEach(() => vi.clearAllMocks());

  it('lista SEM o token (select não pede token) e SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findMany.mockResolvedValue([]);
    await service.list();
    const arg = prisma.dispositivo.findMany.mock.calls[0][0];
    expect('token' in arg.select).toBe(false);
    expect(JSON.stringify(arg)).not.toContain('tenantId');
  });
});

describe('DispositivoService.revogar', () => {
  beforeEach(() => vi.clearAllMocks());

  it('seta ativo=false quando existe', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue({ id: 'd-1' });
    prisma.dispositivo.update.mockResolvedValue({ id: 'd-1', ativo: false });
    await service.revogar('d-1');
    expect(prisma.dispositivo.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'd-1' },
        data: { ativo: false },
      }),
    );
    // where sem tenantId manual (middleware injeta).
    expect('tenantId' in prisma.dispositivo.update.mock.calls[0][0].where).toBe(
      false,
    );
  });

  it('404 quando o dispositivo não existe (outro tenant → null)', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue(null);
    await expect(service.revogar('x')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});

describe('DispositivoService.reparear', () => {
  beforeEach(() => vi.clearAllMocks());

  it('gera novo código e limpa token/pareado', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      nome: 'Totem',
    });
    prisma.dispositivo.update.mockResolvedValue({});
    const res = await service.reparear('d-1');
    expect(res.codigoPareamento).toMatch(/^\d{6}$/);
    const data = prisma.dispositivo.update.mock.calls[0][0].data;
    expect(data.token).toBe(null);
    expect(data.pareado).toBe(false);
    expect(data.codigoPareamento).toMatch(/^\d{6}$/);
  });
});

describe('DispositivoService.parear', () => {
  beforeEach(() => vi.clearAllMocks());

  const futuro = () => new Date(Date.now() + 5 * 60 * 1000);
  const passado = () => new Date(Date.now() - 60 * 1000);

  it('código inexistente → BadRequest genérico', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue(null);
    await expect(service.parear('000000')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.dispositivo.updateMany).not.toHaveBeenCalled();
  });

  it('código expirado → BadRequest', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      nome: 'Totem',
      ativo: true,
      pareado: false,
      codigoExpiraEm: passado(),
    });
    await expect(service.parear('123456')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.dispositivo.updateMany).not.toHaveBeenCalled();
  });

  it('já pareado → BadRequest', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      nome: 'Totem',
      ativo: true,
      pareado: true,
      codigoExpiraEm: futuro(),
    });
    await expect(service.parear('123456')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('inativo → BadRequest', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      nome: 'Totem',
      ativo: false,
      pareado: false,
      codigoExpiraEm: futuro(),
    });
    await expect(service.parear('123456')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('válido → gera token (hex 64) e grava pareado, retorna { token, nome }', async () => {
    const { service, prisma } = makeService();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      nome: 'Totem entrada',
      ativo: true,
      pareado: false,
      codigoExpiraEm: futuro(),
    });
    prisma.dispositivo.updateMany.mockResolvedValue({ count: 1 });

    const res = await service.parear('123456');

    expect(res.nome).toBe('Totem entrada');
    expect(res.token).toMatch(/^[0-9a-f]{64}$/);

    const upd = prisma.dispositivo.updateMany.mock.calls[0][0];
    expect(upd.data.token).toBe(res.token);
    expect(upd.data.pareado).toBe(true);
    expect(upd.data.codigoPareamento).toBe(null);
    expect(upd.data.codigoExpiraEm).toBe(null);
  });
});
