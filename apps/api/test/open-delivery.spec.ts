import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { OpenDeliveryAppService } from '../src/open-delivery/open-delivery-app.service';
import { OpenDeliveryCatalogService } from '../src/open-delivery/open-delivery-catalog.service';
import { OpenDeliveryTokenService } from '../src/open-delivery/open-delivery-token.service';
import { TenantContext } from '../src/tenant/tenant-context';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { CatalogoPublicacaoService } from '../src/catalogo/catalogo-publicacao.service';
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

function makeCatalogService() {
  const prisma = {
    tenant: {
      findFirst: vi.fn().mockResolvedValue({ id: 't-1', nome: 'Burger X' }),
    },
  };
  const publicacao = { getPublicado: vi.fn() };
  const service = new OpenDeliveryCatalogService(
    prisma as unknown as PrismaService,
    publicacao as unknown as CatalogoPublicacaoService,
  );
  return { service, prisma, publicacao };
}

const ctx = { tenantId: 't-1', userId: 'app-1', papel: 'open_delivery' };

describe('OpenDeliveryCatalogService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('merchant devolve id+name; recusa merchantId de outro tenant (403)', async () => {
    const { service } = makeCatalogService();
    const m = await TenantContext.run(ctx, () => service.merchant('t-1'));
    expect(m).toEqual({ id: 't-1', name: 'Burger X' });
    await expect(
      TenantContext.run(ctx, () => service.merchant('outro')),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('catalog mapeia snapshot → Open Delivery (reais, externalCode, status)', async () => {
    const { service, publicacao } = makeCatalogService();
    publicacao.getPublicado.mockResolvedValue({
      versao: 3,
      atualizado: true,
      snapshot: {
        categorias: [{ id: 'c1', nome: 'Burgers', ordem: 0 }],
        produtos: [
          {
            id: 'p1',
            nome: 'X-Burger',
            descricao: 'Clássico',
            precoCentavos: 2990,
            disponivel: true,
            imagemUrl: 'https://img/x.png',
            selo: 'Mais vendido',
            categoriaId: 'c1',
            externalRefs: [{ sistema: 'regem', codigo_pdv: '101' }],
            grupos: [
              {
                id: 'g1',
                nome: 'Adicionais',
                min: 0,
                max: 3,
                ordem: 0,
                opcoes: [
                  {
                    id: 'o1',
                    nome: 'Bacon',
                    precoCentavosDelta: 400,
                    disponivel: false,
                    ordem: 0,
                    externalRefs: [{ sistema: 'regem', codigo_pdv: '201' }],
                  },
                ],
              },
            ],
          },
        ],
      },
    });

    const cat = await TenantContext.run(ctx, () => service.catalog('t-1'));
    expect(cat.merchant).toEqual({ id: 't-1', name: 'Burger X' });
    expect(cat.categories).toEqual([{ id: 'c1', name: 'Burgers', index: 0 }]);
    const item = cat.items[0];
    expect(item).toMatchObject({
      id: 'p1',
      name: 'X-Burger',
      externalCode: '101',
      categoryId: 'c1',
      price: { value: 29.9, currency: 'BRL' },
      status: 'AVAILABLE',
      badge: 'Mais vendido',
    });
    const opt = item.optionGroups[0].options[0];
    expect(opt).toMatchObject({
      name: 'Bacon',
      externalCode: '201',
      price: { value: 4, currency: 'BRL' },
      status: 'UNAVAILABLE', // opção indisponível
    });
  });
});
