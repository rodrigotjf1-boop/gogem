import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Prisma } from '@prisma/client';
import { IntegracaoService } from '../src/integracao/integracao.service';
import { RegemCredencialRecusadaError } from '../src/integracoes/regem/chamada-regem';
import { RegemAvisosService } from '../src/integracoes/regem/regem-avisos.service';
import { SECRET_MASK } from '../src/integracao/conectores';
import {
  ENV_CHAVE_DOS_SEGREDOS,
  buscaDoSegredo,
  segredoDa,
} from '../src/integracao/segredos';
import { TenantContext } from '../src/tenant/tenant-context';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import type { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import type { RegemImportService } from '../src/integracoes/regem/regem-import.service';

// Chave de teste de baixa entropia (32 bytes iguais): só vale aqui.
const CHAVE_DE_TESTE = Buffer.alloc(32, 7).toString('base64');
const TOKEN_NOVO = 'token-de-teste-do-regem';

/** O segredo guardado na linha, aberto com a chave de teste. */
const aberto = (row: any, campo: string) =>
  segredoDa(
    { tenantId: 't1', unidadeId: null, tipo: row.tipo, config: row.config },
    campo,
    Buffer.alloc(32, 7),
  );

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
  const auditoria = { registrar: vi.fn() };
  // A situação dos avisos é pura (lê a coluna); o registro e o desligamento são simulados.
  const real = new RegemAvisosService(
    {} as unknown as PrismaService,
    {} as unknown as RegemConfigResolver,
  );
  const avisos = {
    situacao: vi.fn((a: unknown) => real.situacao(a)),
    garantirRegistro: vi.fn().mockResolvedValue({
      ligados: true,
      registradoEm: '2026-10-20T03:00:00.000Z',
      erro: null,
      detalhe: 'Avisos do Regem: ligados (assinados).',
    }),
    desligar: vi.fn(),
  };
  const service = new IntegracaoService(
    prisma as unknown as PrismaService,
    resolver as unknown as RegemConfigResolver,
    catalog as unknown as RegemCatalogClient,
    regemImport as unknown as RegemImportService,
    auditoria as unknown as import('../src/auditoria/auditoria.service').AuditoriaService,
    avisos as unknown as RegemAvisosService,
  );
  return {
    service,
    prisma,
    resolver,
    catalog,
    regemImport,
    store,
    auditoria,
    avisos,
  };
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
  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(TenantContext, 'getTenantId').mockReturnValue('t1');
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE_DE_TESTE;
  });
  afterEach(() => {
    vi.restoreAllMocks();
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
  });

  it('cria quando não existe (tenantId omitido — vem do middleware)', async () => {
    const { service, prisma } = makeService();
    await service.upsert('regem', {
      config: { apiBase: 'https://a/api/v1', token: TOKEN_NOVO },
      ativo: true,
    });
    expect(prisma.integracao.create).toHaveBeenCalledTimes(1);
    const data = prisma.integracao.create.mock.calls[0][0].data;
    expect(data.tipo).toBe('regem');
    expect(JSON.stringify(data)).not.toContain('tenantId');
  });

  it('token novo vai cifrado para o banco, com o resumo de busca', async () => {
    const { service, prisma } = makeService();
    await service.upsert('regem', {
      config: { apiBase: 'https://a/api/v1', token: TOKEN_NOVO },
      ativo: true,
    });
    const data = prisma.integracao.create.mock.calls[0][0].data;
    expect(JSON.stringify(data)).not.toContain(TOKEN_NOVO);
    expect(data.config.token).toMatch(/^v1\./);
    expect(data.config.apiBase).toBe('https://a/api/v1'); // não-segredo: claro
    expect(data.segredoBusca).toBe(buscaDoSegredo(TOKEN_NOVO));
    expect(aberto(data, 'token')).toBe(TOKEN_NOVO);
  });

  it('access token do Mercado Pago também vai cifrado (sem resumo)', async () => {
    const { service, prisma } = makeService();
    await service.upsert('mercadopago', {
      config: { accessToken: 'mp-token-de-teste' },
    });
    const data = prisma.integracao.create.mock.calls[0][0].data;
    expect(JSON.stringify(data)).not.toContain('mp-token-de-teste');
    expect(aberto(data, 'accessToken')).toBe('mp-token-de-teste');
    expect(data.segredoBusca).toBeNull();
  });

  it('sem a chave no servidor, token novo é recusado e nada é gravado', async () => {
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
    const { service, prisma } = makeService();
    await expect(
      service.upsert('regem', {
        config: { apiBase: 'https://a/api/v1', token: TOKEN_NOVO },
      }),
    ).rejects.toMatchObject({ status: 503 });
    expect(prisma.integracao.create).not.toHaveBeenCalled();
    expect(prisma.integracao.update).not.toHaveBeenCalled();
  });

  it('sem a chave, editar só a URL mantém o token antigo e preenche o resumo', async () => {
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
    const { service, store } = makeService([
      {
        id: 'i1',
        tenantId: 't1',
        unidadeId: null,
        tipo: 'regem',
        ativo: true,
        nome: null,
        config: { apiBase: 'https://old/api/v1', token: 'GUARDADO' },
        segredoBusca: null,
        ultimoTeste: null,
      },
    ]);
    await service.upsert('regem', {
      config: { apiBase: 'https://novo/api/v1', token: '' },
    });
    expect(store[0].config.apiBase).toBe('https://novo/api/v1');
    expect(store[0].config.token).toBe('GUARDADO');
    expect(store[0].segredoBusca).toBe(buscaDoSegredo('GUARDADO'));
  });

  it('token em branco mantém o guardado (não apaga ao reeditar)', async () => {
    const { service, store } = makeService([
      {
        id: 'i1',
        tenantId: 't1',
        unidadeId: null,
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
    // Preservado — e, como estava em claro, sai cifrado nesta gravação.
    expect(store[0].config.token).toMatch(/^v1\./);
    expect(aberto(store[0], 'token')).toBe('GUARDADO');
  });

  it('a máscara como token também mantém o guardado', async () => {
    const { service, store } = makeService([
      {
        id: 'i1',
        tenantId: 't1',
        unidadeId: null,
        tipo: 'regem',
        ativo: false,
        nome: null,
        config: { apiBase: 'https://x/api/v1', token: 'GUARDADO' },
        ultimoTeste: null,
      },
    ]);
    await service.upsert('regem', { config: { token: SECRET_MASK } });
    expect(aberto(store[0], 'token')).toBe('GUARDADO');
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

describe('Regem — token de integração (rgm_it_), fase 3 da credencial própria', () => {
  // Valor de teste de baixa entropia (não é um token de verdade).
  const TOKEN_INTEGRACAO = `rgm_it_${'b'.repeat(43)}`;
  const linhaRegem = (extra: Record<string, unknown> = {}) => ({
    id: 'i1',
    tenantId: 't1',
    unidadeId: null,
    tipo: 'regem',
    ativo: true,
    nome: null,
    segredoBusca: null,
    config: { apiBase: 'https://x/api/v1', token: 'GUARDADO' },
    ultimoTeste: null,
    ...extra,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(TenantContext, 'getTenantId').mockReturnValue('t1');
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE_DE_TESTE;
  });
  afterEach(() => {
    vi.restoreAllMocks();
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
  });

  it('token fora do formato é recusado no salvar, com o que fazer, e nada é gravado', async () => {
    const { service, prisma } = makeService([linhaRegem()]);
    await expect(
      service.upsert('regem', { config: { tokenIntegracao: 'rgm_it_curto' } }),
    ).rejects.toThrow(/começa com "rgm_it_" e tem 50/);
    expect(prisma.integracao.update).not.toHaveBeenCalled();
  });

  it('token no formato vai cifrado e limpa a recusa marcada (reconectou)', async () => {
    const recusa = {
      ok: false,
      detalhe: 'recusado',
      em: '2026-10-19T22:00:00.000Z',
      credencialRecusada: { status: 401, detalhe: 'revogado', em: 'x' },
    };
    const { service, store } = makeService([
      linhaRegem({ ultimoTeste: recusa }),
    ]);
    await service.upsert('regem', {
      config: { tokenIntegracao: TOKEN_INTEGRACAO },
    });
    expect(store[0].config.tokenIntegracao).toMatch(/^v1\./);
    expect(JSON.stringify(store[0].config)).not.toContain(TOKEN_INTEGRACAO);
    expect(aberto(store[0], 'tokenIntegracao')).toBe(TOKEN_INTEGRACAO);
    expect(store[0].ultimoTeste).toBe(Prisma.DbNull);
  });

  it('salvar sem mexer no token novo não limpa o último teste', async () => {
    const teste = { ok: true, detalhe: 'ok', em: 'x' };
    const { service, store } = makeService([
      linhaRegem({ ultimoTeste: teste }),
    ]);
    await service.upsert('regem', { config: { apiBase: 'https://y/api/v1' } });
    expect(store[0].ultimoTeste).toEqual(teste);
  });

  // ERR-036: salvar o token (20/10) apagou a lista "ignorar" das novidades — ela não é campo da tela.
  it('salvar a integração mantém a lista "ignorar" das novidades, e não a aceita da entrada', async () => {
    const { service, store } = makeService([
      linhaRegem({
        config: {
          apiBase: 'https://x/api/v1',
          token: 'GUARDADO',
          ignorados: ['cw1', '45'],
        },
      }),
    ]);
    await service.upsert('regem', {
      config: {
        tokenIntegracao: TOKEN_INTEGRACAO,
        ignorados: 'tudo',
      } as unknown as Record<string, string>,
    });
    expect(store[0].config.ignorados).toEqual(['cw1', '45']);
    expect(store[0].config.tokenIntegracao).toMatch(/^v1\./);
  });

  it('"Testar conexão" diz por qual token passou e chama mesmo com a recusa marcada', async () => {
    const { service, resolver, catalog, store } = makeService([linhaRegem()]);
    resolver.resolve.mockResolvedValue({
      base: 'https://x/api/v1',
      token: 'GUARDADO',
      tokenIntegracao: TOKEN_INTEGRACAO,
      integracaoId: 'i1',
      credencialRecusada: { status: 401, detalhe: 'revogado', em: 'x' },
    });
    catalog.fetchCatalogoWith.mockResolvedValue({ produtos: [{}, {}] });
    const res = await service.testar('regem');
    expect(catalog.fetchCatalogoWith).toHaveBeenCalledWith(expect.anything(), {
      ignorarRecusa: true,
    });
    expect(res.ok).toBe(true);
    expect(res.detalhe).toContain('pelo token de integração');
    // O teste que passou substitui a recusa: as chamadas voltam a ir ao Regem.
    expect(store[0].ultimoTeste.credencialRecusada).toBeUndefined();
  });

  it('sem token novo, o teste diz que passou pelo token de sincronização', async () => {
    const { service, resolver, catalog } = makeService([linhaRegem()]);
    resolver.resolve.mockResolvedValue({
      base: 'https://x/api/v1',
      token: 'GUARDADO',
    });
    catalog.fetchCatalogoWith.mockResolvedValue({ produtos: [] });
    const res = await service.testar('regem');
    expect(res.detalhe).toContain('pelo token de sincronização');
  });

  it('"Testar conexão" recusado de novo mantém a recusa marcada, com o que fazer', async () => {
    const { service, resolver, catalog, store } = makeService([linhaRegem()]);
    resolver.resolve.mockResolvedValue({
      base: 'https://x/api/v1',
      token: 'GUARDADO',
      tokenIntegracao: TOKEN_INTEGRACAO,
      integracaoId: 'i1',
      credencialRecusada: null,
    });
    catalog.fetchCatalogoWith.mockRejectedValue(
      new RegemCredencialRecusadaError(401, 'Token revogado.'),
    );
    const res = await service.testar('regem');
    expect(res.ok).toBe(false);
    expect(res.detalhe).toContain('Emita outro token no Regem');
    expect(store[0].ultimoTeste.credencialRecusada).toMatchObject({
      status: 401,
      detalhe: 'Token revogado.',
    });
  });
});

describe('Regem — avisos assinados (contrato 1), ligar pelo "Testar conexão"', () => {
  const TOKEN_INTEGRACAO = `rgm_it_${'d'.repeat(43)}`;
  const linhaRegem = (extra: Record<string, unknown> = {}) => ({
    id: 'i1',
    tenantId: 't1',
    unidadeId: null,
    tipo: 'regem',
    ativo: true,
    nome: null,
    segredoBusca: null,
    config: { apiBase: 'https://x/api/v1', token: 'GUARDADO' },
    ultimoTeste: null,
    avisos: null,
    ...extra,
  });
  const cfgComToken = {
    base: 'https://x/api/v1',
    token: 'GUARDADO',
    tokenIntegracao: TOKEN_INTEGRACAO,
    integracaoId: 'i1',
    credencialRecusada: null,
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(TenantContext, 'getTenantId').mockReturnValue('t1');
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE_DE_TESTE;
  });
  afterEach(() => {
    vi.restoreAllMocks();
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
  });

  it('conexão ok com o token novo → liga os avisos e diz no resultado', async () => {
    const { service, resolver, catalog, avisos } = makeService([linhaRegem()]);
    resolver.resolve.mockResolvedValue(cfgComToken);
    catalog.fetchCatalogoWith.mockResolvedValue({ produtos: [{}] });
    const res = await service.testar('regem');
    expect(avisos.garantirRegistro).toHaveBeenCalledWith(cfgComToken, {
      forcar: true,
    });
    expect(res.detalhe).toContain('Avisos do Regem: ligados (assinados).');
  });

  it('sem o token novo, o teste não mexe nos avisos', async () => {
    const { service, resolver, catalog, avisos } = makeService([linhaRegem()]);
    resolver.resolve.mockResolvedValue({
      base: 'https://x/api/v1',
      token: 'GUARDADO',
    });
    catalog.fetchCatalogoWith.mockResolvedValue({ produtos: [] });
    await service.testar('regem');
    expect(avisos.garantirRegistro).not.toHaveBeenCalled();
  });

  it('conexão que falha não liga avisos', async () => {
    const { service, resolver, catalog, avisos } = makeService([linhaRegem()]);
    resolver.resolve.mockResolvedValue(cfgComToken);
    catalog.fetchCatalogoWith.mockRejectedValue(new Error('caiu'));
    await service.testar('regem');
    expect(avisos.garantirRegistro).not.toHaveBeenCalled();
  });

  it('token novo salvo: o registro dos avisos morre no Regem — fica "não ligado", e o segredo vira o anterior no próximo teste', async () => {
    const ligado = {
      segredo: 'v1.aaa.bbb.ccc',
      anterior: null,
      trocadoEm: null,
      resumoDoToken: 'resumo-velho',
      registradoEm: '2026-10-20T03:00:00.000Z',
      tentadoEm: '2026-10-20T03:00:00.000Z',
      erro: null,
    };
    const { service, store } = makeService([linhaRegem({ avisos: ligado })]);
    await service.upsert('regem', {
      config: { tokenIntegracao: TOKEN_INTEGRACAO },
    });
    expect(store[0].avisos).toMatchObject({
      segredo: 'v1.aaa.bbb.ccc',
      resumoDoToken: 'resumo-velho',
      registradoEm: null,
    });
    const view = (await service.list()).find((i) => i.tipo === 'regem')!;
    expect(view.avisos?.ligados).toBe(false);
  });

  it('a tela recebe a situação dos avisos (sem segredo) só no Regem', async () => {
    const { service } = makeService([
      linhaRegem({
        avisos: {
          segredo: 'v1.segredo.cifrado.aqui',
          resumoDoToken: 'r',
          registradoEm: '2026-10-20T03:00:00.000Z',
        },
      }),
    ]);
    const lista = await service.list();
    const r = lista.find((i) => i.tipo === 'regem')!;
    expect(r.avisos).toMatchObject({ ligados: true, erro: null });
    expect(JSON.stringify(r)).not.toContain('v1.segredo.cifrado.aqui');
    expect(lista.find((i) => i.tipo === 'mercadopago')!.avisos).toBeNull();
  });

  it('desligar → chama o Regem pelo serviço dos avisos e audita', async () => {
    const { service, resolver, avisos, auditoria } = makeService([
      linhaRegem(),
    ]);
    resolver.resolve.mockResolvedValue(cfgComToken);
    avisos.desligar.mockResolvedValue({
      ligados: false,
      registradoEm: null,
      erro: null,
      detalhe: 'Avisos do Regem desligados: o Regem voltou ao caminho antigo.',
    });
    const s = await service.desligarAvisos('regem');
    expect(avisos.desligar).toHaveBeenCalledWith(cfgComToken);
    expect(s.ligados).toBe(false);
    expect(auditoria.registrar).toHaveBeenCalledWith(
      expect.objectContaining({ acao: 'integracao.avisos.desligar' }),
    );
  });

  it('desligar em conector sem avisos → 400', async () => {
    const { service } = makeService([]);
    await expect(service.desligarAvisos('mercadopago')).rejects.toThrow(
      /não tem avisos assinados/,
    );
  });
});
