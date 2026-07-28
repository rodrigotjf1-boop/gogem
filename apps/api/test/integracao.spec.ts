import { beforeEach, describe, expect, it, vi } from 'vitest';
import { IntegracaoService } from '../src/integracao/integracao.service';
import { SECRET_MASK } from '../src/integracao/conectores';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import type { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import type { RegemImportService } from '../src/integracoes/regem/regem-import.service';

function makeService(rows: any[] = []) {
  const store = [...rows];
  const prisma = {
    integracao: {
      findMany: vi.fn().mockImplementation(async () => store),
      findFirst: vi
        .fn()
        .mockImplementation(async ({ where }: any) =>
          store.find((r) => r.tipo === where.tipo),
        ),
      create: vi.fn().mockImplementation(async ({ data }: any) => {
        const row = { id: `int-${store.length + 1}`, ...data };
        store.push(row);
        return row;
      }),
      update: vi.fn().mockImplementation(async ({ where, data }: any) => {
        const row = store.find((r) => r.id === where.id);
        Object.assign(row, data);
        return row;
      }),
    },
  };
  const resolver = { resolve: vi.fn() };
  const catalog = { fetchCatalogoWith: vi.fn() };
  const regemImport = { importar: vi.fn() };
  const service = new IntegracaoService(
    prisma as unknown as PrismaService,
    resolver as unknown as RegemConfigResolver,
    catalog as unknown as RegemCatalogClient,
    regemImport as unknown as RegemImportService,
  );
  return { service, prisma, resolver, catalog, regemImport, store };
}

describe('IntegracaoService.list — máscara de segredos', () => {
  it('mascara o token e mostra a URL; open_delivery aparece indisponível', async () => {
    const { service } = makeService([
      {
        id: 'i1',
        tipo: 'regem',
        ativo: true,
        nome: null,
        config: { apiBase: 'https://api.x/api/v1', token: 'SECRETO' },
        ultimoTeste: null,
      },
    ]);
    const list = await service.list();
    const regem = list.find((i) => i.tipo === 'regem')!;
    const apiBase = regem.campos.find((c) => c.key === 'apiBase')!;
    const token = regem.campos.find((c) => c.key === 'token')!;

    expect(regem.ativo).toBe(true);
    expect(regem.configurado).toBe(true);
    expect(apiBase.valor).toBe('https://api.x/api/v1'); // não-segredo: visível
    expect(token.secret).toBe(true);
    expect(token.preenchido).toBe(true);
    expect(token.valor).toBe(SECRET_MASK); // segredo: mascarado
    expect(JSON.stringify(regem)).not.toContain('SECRETO'); // nunca vaza

    const od = list.find((i) => i.tipo === 'open_delivery')!;
    expect(od.disponivel).toBe(false);
  });
});

describe('IntegracaoService.upsert — merge de segredos', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cria quando não existe (tenantId omitido — vem do middleware)', async () => {
    const { service, prisma } = makeService();
    await service.upsert('regem', {
      config: { apiBase: 'https://a/api/v1', token: 'T1' },
      ativo: true,
    });
    expect(prisma.integracao.create).toHaveBeenCalledTimes(1);
    const data = prisma.integracao.create.mock.calls[0][0].data;
    expect(data.tipo).toBe('regem');
    expect(JSON.stringify(data)).not.toContain('tenantId');
  });

  it('token em branco mantém o guardado (não apaga ao reeditar)', async () => {
    const { service, store } = makeService([
      {
        id: 'i1',
        tipo: 'regem',
        ativo: true,
        nome: null,
        config: { apiBase: 'https://old/api/v1', token: 'GUARDADO' },
        ultimoTeste: null,
      },
    ]);
    // Reedita só a URL; token vazio.
    await service.upsert('regem', {
      config: { apiBase: 'https://novo/api/v1', token: '' },
    });
    expect(store[0].config.apiBase).toBe('https://novo/api/v1');
    expect(store[0].config.token).toBe('GUARDADO'); // preservado
  });

  it('a máscara como token também mantém o guardado', async () => {
    const { service, store } = makeService([
      {
        id: 'i1',
        tipo: 'regem',
        ativo: false,
        nome: null,
        config: { apiBase: 'https://x/api/v1', token: 'GUARDADO' },
        ultimoTeste: null,
      },
    ]);
    await service.upsert('regem', { config: { token: SECRET_MASK } });
    expect(store[0].config.token).toBe('GUARDADO');
  });

  it('ativar com config incompleta → 400', async () => {
    const { service } = makeService();
    await expect(
      service.upsert('regem', {
        config: { apiBase: 'https://a/api/v1' },
        ativo: true,
      }),
    ).rejects.toThrow(/antes de ativá-la/);
  });

  it('conector indisponível (open_delivery) → 400', async () => {
    const { service } = makeService();
    await expect(
      service.upsert('open_delivery', { config: { baseUrl: 'https://a' } }),
    ).rejects.toThrow(/ainda não está disponível/);
  });

  it('conector desconhecido → 404', async () => {
    const { service } = makeService();
    await expect(service.upsert('zap', {})).rejects.toThrow(/desconhecido/);
  });
});

describe('IntegracaoService.testar', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sucesso: chama fetchCatalogoWith e persiste ultimoTeste ok', async () => {
    const { service, resolver, catalog, store } = makeService([
      {
        id: 'i1',
        tipo: 'regem',
        ativo: false,
        nome: null,
        config: { apiBase: 'https://x/api/v1', token: 'T' },
        ultimoTeste: null,
      },
    ]);
    resolver.resolve.mockResolvedValue({
      base: 'https://x/api/v1',
      token: 'T',
    });
    catalog.fetchCatalogoWith.mockResolvedValue({ produtos: [{}, {}, {}] });

    const res = await service.testar('regem');
    expect(resolver.resolve).toHaveBeenCalledWith({ ignoreActive: true });
    expect(res.ok).toBe(true);
    expect(res.detalhe).toContain('3 produto');
    expect(store[0].ultimoTeste.ok).toBe(true);
  });

  it('falha: devolve ok=false com o motivo (não lança)', async () => {
    const { service, resolver, store } = makeService([
      {
        id: 'i1',
        tipo: 'regem',
        ativo: false,
        nome: null,
        config: { apiBase: 'https://x/api/v1', token: 'T' },
        ultimoTeste: null,
      },
    ]);
    resolver.resolve.mockRejectedValue(new Error('token inválido'));
    const res = await service.testar('regem');
    expect(res.ok).toBe(false);
    expect(res.detalhe).toContain('token inválido');
    expect(store[0].ultimoTeste.ok).toBe(false);
  });
});

describe('IntegracaoService.importar', () => {
  it('regem → delega ao RegemImportService', async () => {
    const { service, regemImport } = makeService();
    regemImport.importar.mockResolvedValue({ geradoEm: 'x' });
    await service.importar('regem');
    expect(regemImport.importar).toHaveBeenCalledTimes(1);
  });
});
