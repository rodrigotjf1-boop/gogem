import { UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { OpenDeliveryAppService } from '../src/open-delivery/open-delivery-app.service';
import { OpenDeliveryTokenService } from '../src/open-delivery/open-delivery-token.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { JwtService } from '@nestjs/jwt';

function makeAppService() {
  const prisma = {
    openDeliveryApp: {
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
    },
  };
  const service = new OpenDeliveryAppService(
    prisma as unknown as PrismaService,
  );
  return { service, prisma };
}

describe('OpenDeliveryAppService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('criar gera clientId/clientSecret, guarda só o HASH e usa escopos padrão', async () => {
    const { service, prisma } = makeAppService();
    prisma.openDeliveryApp.create.mockImplementation(({ data }: any) => ({
      id: 'app-1',
      nome: data.nome,
      escopos: data.escopos,
      ativo: true,
    }));

    const r = await service.criar({ nome: 'iFood' });

    expect(r.clientId).toMatch(/^od_[0-9a-f]{24}$/);
    expect(r.clientSecret).toHaveLength(48); // 24 bytes hex
    expect(r.escopos).toEqual(['catalog:read', 'orders:write']);
    // No banco vai o hash bcrypt, NUNCA o segredo em claro.
    const data = prisma.openDeliveryApp.create.mock.calls[0][0].data;
    expect(data.clientSecretHash).toMatch(/^\$2[aby]\$/);
    expect(data.clientSecretHash).not.toBe(r.clientSecret);
    expect(await bcrypt.compare(r.clientSecret, data.clientSecretHash)).toBe(
      true,
    );
    expect('tenantId' in data).toBe(false); // middleware injeta (§2)
  });

  it('criar respeita escopos informados', async () => {
    const { service, prisma } = makeAppService();
    prisma.openDeliveryApp.create.mockImplementation(({ data }: any) => ({
      id: 'app-2',
      nome: data.nome,
      escopos: data.escopos,
      ativo: true,
    }));
    const r = await service.criar({
      nome: 'Parceiro',
      escopos: ['catalog:read'],
    });
    expect(r.escopos).toEqual(['catalog:read']);
  });

  it('revogar desativa o app (404 se não existir)', async () => {
    const { service, prisma } = makeAppService();
    prisma.openDeliveryApp.findFirst.mockResolvedValue({ id: 'app-1' });
    prisma.openDeliveryApp.update.mockResolvedValue({});
    await service.revogar('app-1');
    expect(prisma.openDeliveryApp.update).toHaveBeenCalledWith({
      where: { id: 'app-1' },
      data: { ativo: false },
    });
    prisma.openDeliveryApp.findFirst.mockResolvedValue(null);
    await expect(service.revogar('x')).rejects.toThrow();
  });
});

function makeTokenService() {
  const prisma = {
    openDeliveryApp: {
      findFirst: vi.fn(),
      update: vi.fn().mockResolvedValue({}),
    },
  };
  const jwt = { sign: vi.fn().mockReturnValue('jwt-od') };
  const service = new OpenDeliveryTokenService(
    prisma as unknown as PrismaService,
    jwt as unknown as JwtService,
  );
  return { service, prisma, jwt };
}

describe('OpenDeliveryTokenService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('emite token para clientId/secret válidos (aud open-delivery + tenant do app)', async () => {
    const { service, prisma, jwt } = makeTokenService();
    const hash = await bcrypt.hash('segredo', 10);
    prisma.openDeliveryApp.findFirst.mockResolvedValue({
      id: 'app-1',
      tenantId: 't-1',
      ativo: true,
      clientSecretHash: hash,
      escopos: ['catalog:read'],
    });

    const r = await service.emitir({
      grant_type: 'client_credentials',
      client_id: 'od_abc',
      client_secret: 'segredo',
    });

    expect(r).toEqual({
      access_token: 'jwt-od',
      token_type: 'Bearer',
      expires_in: 3600,
    });
    const payload = jwt.sign.mock.calls[0][0];
    expect(payload).toMatchObject({
      sub: 'app-1',
      tenantId: 't-1',
      aud: 'open-delivery',
      escopos: ['catalog:read'],
    });
    // Registra o uso.
    expect(prisma.openDeliveryApp.update).toHaveBeenCalled();
  });

  it('rejeita secret errado', async () => {
    const { service, prisma } = makeTokenService();
    prisma.openDeliveryApp.findFirst.mockResolvedValue({
      id: 'app-1',
      tenantId: 't-1',
      ativo: true,
      clientSecretHash: await bcrypt.hash('certo', 10),
      escopos: [],
    });
    await expect(
      service.emitir({
        grant_type: 'client_credentials',
        client_id: 'od_abc',
        client_secret: 'errado',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejeita app inativo (revogado)', async () => {
    const { service, prisma } = makeTokenService();
    prisma.openDeliveryApp.findFirst.mockResolvedValue({
      id: 'app-1',
      tenantId: 't-1',
      ativo: false,
      clientSecretHash: await bcrypt.hash('segredo', 10),
      escopos: [],
    });
    await expect(
      service.emitir({
        grant_type: 'client_credentials',
        client_id: 'od_abc',
        client_secret: 'segredo',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejeita clientId inexistente', async () => {
    const { service, prisma } = makeTokenService();
    prisma.openDeliveryApp.findFirst.mockResolvedValue(null);
    await expect(
      service.emitir({
        grant_type: 'client_credentials',
        client_id: 'nope',
        client_secret: 'x',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
