import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Prisma } from '@prisma/client';
import {
  RegemCredencialRecusadaError,
  RegemLimiteError,
  cabecalhosDoRegem,
  chamarRegem,
  esquecerEsperasDoRegem,
  mensagemDoRegem,
  segundosDoRetryAfter,
} from '../src/integracoes/regem/chamada-regem';
import { causaDeRede } from '../src/common/causa-de-rede';
import { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import { RegemPauseClient } from '../src/integracoes/regem/regem-pause.client';
import {
  RegemRecusouError,
  RegemSalesClient,
} from '../src/integracoes/regem/regem-sales.client';
import {
  RegemConfigResolver,
  type RegemConfig,
} from '../src/integracoes/regem/regem-config.resolver';
import { cifrar } from '../src/common/cifra';
import { contextoDoSegredo } from '../src/integracao/segredos';
import type { PrismaService } from '../src/prisma/prisma.service';

/**
 * Fase 3 da credencial própria do GoGeM (Hub DMS): o GoGeM chama as 5 rotas do Regem com o
 * token de integração da loja (`Authorization: Bearer rgm_it_…`), o contrato público da API de
 * integração. Recusa do token novo NÃO volta para o token antigo (decisão do dono, 19/10/2026).
 */

// Valor de teste de baixa entropia (não é um token de verdade).
const TOKEN_NOVO = `rgm_it_${'a'.repeat(43)}`;

const cfgNovo = (extra: Partial<RegemConfig> = {}): RegemConfig => ({
  base: 'https://regem/api/v1',
  token: 'token-antigo',
  tokenIntegracao: TOKEN_NOVO,
  integracaoId: 'integ-1',
  credencialRecusada: null,
  ...extra,
});
const cfgAntigo = (extra: Partial<RegemConfig> = {}): RegemConfig => ({
  base: 'https://regem/api/v1',
  token: 'token-antigo',
  tokenIntegracao: null,
  integracaoId: 'integ-2',
  credencialRecusada: null,
  ...extra,
});

function resolverCom(cfg: RegemConfig) {
  return {
    resolve: vi.fn().mockResolvedValue(cfg),
    marcarCredencialRecusada: vi.fn().mockResolvedValue(undefined),
  };
}

function responde(
  status: number,
  body: unknown,
  headers: Record<string, string> = {},
) {
  const fetchFalso = vi.fn().mockImplementation(
    async () =>
      new Response(typeof body === 'string' ? body : JSON.stringify(body), {
        status,
        headers: { 'content-type': 'application/json', ...headers },
      }),
  );
  vi.stubGlobal('fetch', fetchFalso);
  return fetchFalso;
}

const problema = (status: number, tipo: string, detail: string) => ({
  type: `https://api.dmsregem.com/problemas/${tipo}`,
  title: tipo,
  status,
  detail,
});

function cabecalhos(fetchFalso: ReturnType<typeof vi.fn>, i = 0) {
  return (fetchFalso.mock.calls[i][1] as RequestInit).headers as Record<
    string,
    string
  >;
}

beforeEach(() => esquecerEsperasDoRegem());
afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('cabeçalhos da credencial', () => {
  it('com o token de integração: só o Bearer (sem X-Sync-Token nem X-Integrador)', () => {
    expect(cabecalhosDoRegem(cfgNovo())).toEqual({
      Authorization: `Bearer ${TOKEN_NOVO}`,
    });
  });

  it('sem ele: o caminho de sempre, com X-Integrador', () => {
    expect(cabecalhosDoRegem(cfgAntigo())).toEqual({
      'X-Sync-Token': 'token-antigo',
      'X-Loja-Token': 'token-antigo',
      'X-Integrador': 'gogem',
    });
  });
});

describe('as 5 rotas do totem levam o Bearer quando a loja tem o token novo', () => {
  it('catálogo, pausa, venda, dinheiro e falha', async () => {
    const fetchFalso = responde(200, { produtos: [], comandaId: 'c1' });
    const resolver = resolverCom(cfgNovo()) as unknown as RegemConfigResolver;

    await new RegemCatalogClient(resolver).fetchCatalogo();
    await new RegemPauseClient(resolver).pausar('X1', true);
    const vendas = new RegemSalesClient(resolver);
    await vendas.lancarVendaExterna({
      idempotencyKey: 'k1',
      itens: [{ codigoPdv: 'X1', quantidade: 1 }],
      pagamentos: [{ forma: 'debito', valor: 10 }],
    } as never);
    await vendas.lancarTotemDinheiro({ idempotencyKey: 'k2', itens: [] });
    await vendas.relatarFalha({
      idempotencyKey: 'k3',
      itens: [],
      formaTentada: 'pix',
      totalCentavos: 100,
      motivo: 'recusado',
    });

    const rotas = fetchFalso.mock.calls.map((c) =>
      String(c[0]).replace('https://regem/api/v1', ''),
    );
    expect(rotas).toEqual([
      '/sync/catalogo',
      '/sync/produtos/pausa',
      '/vendas/externa-pdv',
      '/delivery/totem-dinheiro',
      '/vendas/externa-pdv/falha',
    ]);
    for (let i = 0; i < 5; i++) {
      const h = cabecalhos(fetchFalso, i);
      expect(h.Authorization).toBe(`Bearer ${TOKEN_NOVO}`);
      expect(h['X-Sync-Token']).toBeUndefined();
      expect(h['X-Integrador']).toBeUndefined();
    }
  });
});

describe('recusa do token novo (401/403): não volta para o token antigo', () => {
  it('401 → marca a recusa, lança a recusa da credencial e chama UMA vez só', async () => {
    const fetchFalso = responde(
      401,
      problema(
        401,
        'token-invalido',
        'Token de integração ausente, inválido, vencido ou revogado.',
      ),
    );
    const cfg = cfgNovo();
    const resolver = resolverCom(cfg);

    const erro = await new RegemCatalogClient(
      resolver as unknown as RegemConfigResolver,
    )
      .fetchCatalogo()
      .catch((e) => e);

    expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
    expect(erro.status).toBe(401);
    expect(erro.message).toContain('Emita outro token no Regem');
    expect(erro.message).toContain('revogado');
    expect(fetchFalso).toHaveBeenCalledTimes(1); // nunca tenta o X-Sync-Token
    expect(resolver.marcarCredencialRecusada).toHaveBeenCalledWith(
      cfg,
      401,
      'Token de integração ausente, inválido, vencido ou revogado.',
    );
  });

  it('403 (sem o escopo) → a mensagem fala da permissão', async () => {
    responde(
      403,
      problema(
        403,
        'escopo-insuficiente',
        'Este token não tem o escopo totem.vendas.lancar.',
      ),
    );
    const resolver = resolverCom(cfgNovo());
    const erro = await new RegemSalesClient(
      resolver as unknown as RegemConfigResolver,
    )
      .lancarTotemDinheiro({ idempotencyKey: 'k', itens: [] })
      .catch((e) => e);
    expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
    expect(erro.status).toBe(403);
    expect(erro.message).toContain('não tem permissão');
    expect(erro.message).toContain('totem.vendas.lancar');
  });

  it('a recusa da credencial NÃO é recusa da venda: o totem reenvia (não é RegemRecusouError)', async () => {
    responde(401, problema(401, 'token-invalido', 'revogado'));
    const resolver = resolverCom(cfgNovo());
    const erro = await new RegemSalesClient(
      resolver as unknown as RegemConfigResolver,
    )
      .lancarVendaExterna({
        idempotencyKey: 'k',
        itens: [],
        pagamentos: [],
      } as never)
      .catch((e) => e);
    expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
    expect(erro).not.toBeInstanceOf(RegemRecusouError);
  });

  it('com a recusa marcada, as chamadas nem vão ao Regem', async () => {
    const fetchFalso = responde(200, { produtos: [] });
    const cfg = cfgNovo({
      credencialRecusada: {
        status: 401,
        detalhe: 'revogado',
        em: '2026-10-19T22:00:00.000Z',
      },
    });
    const resolver = resolverCom(cfg) as unknown as RegemConfigResolver;

    await expect(
      new RegemCatalogClient(resolver).fetchCatalogo(),
    ).rejects.toBeInstanceOf(RegemCredencialRecusadaError);
    expect(await new RegemPauseClient(resolver).pausar('X1', true)).toBe(false);
    expect(fetchFalso).not.toHaveBeenCalled();
  });

  it('"Testar conexão" chama mesmo com a recusa marcada (é o jeito de reconectar)', async () => {
    const fetchFalso = responde(200, { produtos: [{}] });
    const cfg = cfgNovo({
      credencialRecusada: {
        status: 401,
        detalhe: 'revogado',
        em: '2026-10-19T22:00:00.000Z',
      },
    });
    const catalogo = await new RegemCatalogClient(
      resolverCom(cfg) as unknown as RegemConfigResolver,
    ).fetchCatalogoWith(cfg, { ignorarRecusa: true });
    expect(catalogo.produtos).toHaveLength(1);
    expect(fetchFalso).toHaveBeenCalledTimes(1);
  });

  it('401 no caminho ANTIGO (sem token novo) não marca recusa: segue como sempre', async () => {
    responde(401, { message: 'Token de sync ausente' });
    const resolver = resolverCom(cfgAntigo());
    const erro = await new RegemCatalogClient(
      resolver as unknown as RegemConfigResolver,
    )
      .fetchCatalogo()
      .catch((e) => e);
    expect(erro).not.toBeInstanceOf(RegemCredencialRecusadaError);
    expect(erro.message).toContain('401');
    expect(resolver.marcarCredencialRecusada).not.toHaveBeenCalled();
  });
});

describe('429: espera o Retry-After', () => {
  it('lança o limite, segura as chamadas até a hora e depois volta a chamar', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-10-19T22:00:00.000Z'));
    const fetchFalso = responde(
      429,
      problema(429, 'limite-de-chamadas', 'aguarde'),
      {
        'retry-after': '120',
      },
    );
    const resolver = resolverCom(cfgNovo()) as unknown as RegemConfigResolver;
    const cliente = new RegemCatalogClient(resolver);

    const primeiro = await cliente.fetchCatalogo().catch((e) => e);
    expect(primeiro).toBeInstanceOf(RegemLimiteError);
    expect(primeiro.esperaSeg).toBe(120);

    vi.setSystemTime(new Date('2026-10-19T22:01:00.000Z')); // 60 s depois
    const segundo = await cliente.fetchCatalogo().catch((e) => e);
    expect(segundo).toBeInstanceOf(RegemLimiteError);
    expect(segundo.esperaSeg).toBe(60);
    expect(fetchFalso).toHaveBeenCalledTimes(1);

    vi.setSystemTime(new Date('2026-10-19T22:02:01.000Z')); // passou
    responde(200, { produtos: [] });
    await expect(cliente.fetchCatalogo()).resolves.toEqual({ produtos: [] });
  });

  it('segundosDoRetryAfter: número, data HTTP, ilegível (60 s) e o teto de 24 h', () => {
    const agora = Date.parse('2026-10-19T22:00:00.000Z');
    expect(segundosDoRetryAfter('30', agora)).toBe(30);
    expect(segundosDoRetryAfter('Mon, 19 Oct 2026 22:05:00 GMT', agora)).toBe(
      300,
    );
    expect(segundosDoRetryAfter('daqui a pouco', agora)).toBe(60);
    expect(segundosDoRetryAfter(null, agora)).toBe(60);
    expect(segundosDoRetryAfter('0', agora)).toBe(1);
    expect(segundosDoRetryAfter('999999', agora)).toBe(86400);
  });
});

describe('o texto dos erros do Regem', () => {
  it('problem+json → detail; Nest → message; texto puro → o começo', () => {
    expect(
      mensagemDoRegem(
        JSON.stringify(problema(403, 'escopo-insuficiente', 'Sem o escopo.')),
      ),
    ).toBe('Sem o escopo.');
    expect(mensagemDoRegem(JSON.stringify({ message: ['a', 'b'] }))).toBe(
      'a; b',
    );
    expect(mensagemDoRegem('falhou feio')).toBe('falhou feio');
    expect(mensagemDoRegem('')).toBe('sem detalhe');
  });

  it('a falha de rede leva a causa real, não só "fetch failed"', async () => {
    // Como o fetch do Node lança: "fetch failed", com o motivo em `cause`.
    const semRede = Object.assign(new TypeError('fetch failed'), {
      cause: Object.assign(new Error('getaddrinfo ENOTFOUND api-stg.exemplo'), {
        code: 'ENOTFOUND',
        hostname: 'api-stg.exemplo',
      }),
    });
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(semRede));
    const erro = await chamarRegem(resolverCom(cfgNovo()), cfgNovo(), {
      caminho: '/sync/catalogo',
      metodo: 'GET',
      prazoMs: 1000,
      rotulo: 'o catálogo',
    }).catch((e) => e);
    expect(erro.message).toContain('ENOTFOUND api-stg.exemplo');
    expect(erro.message).not.toContain(TOKEN_NOVO);
  });

  it('causaDeRede: tempo esgotado, query cortada e nada quando não há causa', () => {
    const abortado = Object.assign(new Error('This operation was aborted'), {
      name: 'AbortError',
    });
    expect(causaDeRede(abortado)).toBe('tempo esgotado');
    const comQuery = Object.assign(new TypeError('fetch failed'), {
      cause: new Error('connect failed https://x/y?token=abc'),
    });
    expect(causaDeRede(comQuery)).toBe('connect failed https://x/y');
    expect(causaDeRede(new Error('fetch failed'))).toBeNull();
  });
});

describe('o resolver guarda e devolve a recusa', () => {
  const CHAVE = Buffer.alloc(32, 7); // baixa entropia: só vale aqui
  const dono = { tenantId: 't1', unidadeId: null, tipo: 'regem' };
  const linha = (ultimoTeste: unknown) => ({
    id: 'integ-1',
    ...dono,
    ativo: true,
    ultimoTeste,
    config: {
      apiBase: 'https://regem/api/v1',
      token: cifrar('token-antigo', CHAVE, contextoDoSegredo(dono, 'token')),
      tokenIntegracao: cifrar(
        TOKEN_NOVO,
        CHAVE,
        contextoDoSegredo(dono, 'tokenIntegracao'),
      ),
    },
  });

  beforeEach(() => {
    process.env.GOGEM_CHAVE_DOS_SEGREDOS = CHAVE.toString('base64');
  });
  afterEach(() => {
    delete process.env.GOGEM_CHAVE_DOS_SEGREDOS;
  });

  it('abre o token novo cifrado e devolve a recusa marcada no último teste', async () => {
    const recusa = {
      status: 401,
      detalhe: 'revogado',
      em: '2026-10-19T22:00:00.000Z',
    };
    const prisma = {
      integracao: {
        findFirst: vi.fn().mockResolvedValue(
          linha({
            ok: false,
            detalhe: 'x',
            em: recusa.em,
            credencialRecusada: recusa,
          }),
        ),
      },
    };
    const cfg = await new RegemConfigResolver(
      prisma as unknown as PrismaService,
    ).resolve();
    expect(cfg.tokenIntegracao).toBe(TOKEN_NOVO);
    expect(cfg.integracaoId).toBe('integ-1');
    expect(cfg.credencialRecusada).toEqual(recusa);
  });

  it('teste que passou não é recusa', async () => {
    const prisma = {
      integracao: {
        findFirst: vi
          .fn()
          .mockResolvedValue(linha({ ok: true, detalhe: 'ok', em: 'x' })),
      },
    };
    const cfg = await new RegemConfigResolver(
      prisma as unknown as PrismaService,
    ).resolve();
    expect(cfg.credencialRecusada).toBeNull();
  });

  it('marcarCredencialRecusada grava no último teste o que o painel mostra', async () => {
    const prisma = { integracao: { update: vi.fn().mockResolvedValue({}) } };
    await new RegemConfigResolver(
      prisma as unknown as PrismaService,
    ).marcarCredencialRecusada(cfgNovo(), 401, 'revogado');
    const { where, data } = prisma.integracao.update.mock.calls[0][0];
    expect(where).toEqual({ id: 'integ-1' });
    expect(data.ultimoTeste).toMatchObject({
      ok: false,
      credencialRecusada: { status: 401, detalhe: 'revogado' },
    });
    expect(data.ultimoTeste.detalhe).toContain('Emita outro token no Regem');
    expect(data.ultimoTeste).not.toBe(Prisma.DbNull);
  });
});
