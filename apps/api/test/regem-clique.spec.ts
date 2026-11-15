import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  conferirVolta,
  corpoDoPedido,
  gerarPedido,
  hashDoEstado,
  lerConfigDoClique,
  lojaEmUso,
  lojasDaTroca,
  urlDaPagina,
  PERMISSOES_DO_TOTEM,
} from '../src/integracoes/regem/regem-clique.regras';
import {
  chamarRegem,
  esquecerEsperasDoRegem,
  mensagemDaRecusa,
  RegemCredencialRecusadaError,
} from '../src/integracoes/regem/chamada-regem';
import { esquecerClienteDmsId } from '../src/integracoes/regem/dms-id.cliente';
import {
  ligacaoEmUso,
  lerClique,
  resumoDoClique,
  selarLigacao,
} from '../src/integracoes/regem/clique-guardado';
import type { RegemConfig } from '../src/integracoes/regem/regem-config.resolver';

/**
 * "CONECTAR PELO REGEM" (Hub DMS F6, plano "Clique GoGeM → Regem"): as regras puras, a ligação
 * guardada cifrada e a chamada ao Regem pela ligação (o token do DMS ID + `DMS-Ligacao`, com nova
 * tentativa no 401). Valores de teste fictícios.
 */

const BASE_ENV = {
  GOGEM_REGEM_CLIQUE: 'true',
  DMS_ID_EMISSOR: 'https://id.exemplo/oidc/',
  DMS_ID_APLICATIVO: 'app-gogem-de-teste',
  DMS_ID_SEGREDO: 'segredo-de-teste-123456',
};
const LIGACAO = `dms_lg_regem_${'a'.repeat(43)}_${'b'.repeat(6)}`;
const CHAVE = Buffer.alloc(32, 7);
const DONO = { tenantId: 't1', unidadeId: null, tipo: 'regem' };

describe('a configuração do "Conectar pelo Regem"', () => {
  it('nasce desligada (sem GOGEM_REGEM_CLIQUE), sem motivo no log', () => {
    expect(lerConfigDoClique({})).toEqual({ ligado: false, motivo: null });
  });

  it('ligada, com os padrões de produção', () => {
    expect(lerConfigDoClique(BASE_ENV)).toEqual({
      ligado: true,
      base: 'https://api.dmsregem.com/api/v1',
      emissorDoRegem: 'https://api.dmsregem.com',
      recurso: 'https://api.dmsregem.com/api/v1/integracao',
      pagina: 'https://app.dmsregem.com/integracoes/autorizar',
      volta: 'https://app.gogem.com.br/integracoes/regem/volta',
      emissorDmsId: 'https://id.exemplo/oidc',
      aplicativo: 'app-gogem-de-teste',
      segredo: 'segredo-de-teste-123456',
    });
  });

  it('torta não liga e diz o motivo (para a distribuição)', () => {
    expect(lerConfigDoClique({ ...BASE_ENV, DMS_ID_SEGREDO: '' })).toEqual({
      ligado: false,
      motivo: 'falta DMS_ID_SEGREDO (o aplicativo do GoGeM no DMS ID)',
    });
    expect(
      lerConfigDoClique({
        ...BASE_ENV,
        GOGEM_PAINEL_URL: 'http://app.gogem.com.br',
      }),
    ).toMatchObject({ ligado: false });
    expect(
      lerConfigDoClique({
        ...BASE_ENV,
        GOGEM_REGEM_APP_URL: 'https://app.regem/x',
      }),
    ).toMatchObject({ ligado: false });
  });
});

describe('o pedido, a volta e a troca', () => {
  it('o state e o PKCE S256; o corpo leva as três permissões do totem e a conta', () => {
    const p = gerarPedido();
    expect(p.estadoHash).toBe(hashDoEstado(p.estado));
    expect(p.desafio).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const corpo = corpoDoPedido({
      volta: 'https://app.gogem.com.br/integracoes/regem/volta',
      estado: p.estado,
      desafio: p.desafio,
      contaNome: ' Brasa Burger ',
      contaCnpj: null,
      contaEmail: ' Dono@Brasa.Exemplo ',
    });
    expect(corpo).toEqual({
      response_type: 'code',
      redirect_uri: 'https://app.gogem.com.br/integracoes/regem/volta',
      scope: 'totem.catalogo.ler totem.produtos.pausar totem.vendas.lancar',
      state: p.estado,
      code_challenge: p.desafio,
      code_challenge_method: 'S256',
      conta_nome: 'Brasa Burger',
      conta_email: 'dono@brasa.exemplo',
    });
    const numero = `urn:ietf:params:oauth:request_uri:rgm_${'n'.repeat(43)}`;
    const u = new URL(
      urlDaPagina(
        'https://app.dmsregem.com/integracoes/autorizar',
        'app-gg',
        numero,
      ),
    );
    expect(u.searchParams.get('client_id')).toBe('app-gg');
    expect(u.searchParams.get('request_uri')).toBe(numero);
  });

  it('a volta só vale com o iss do Regem e o state com a forma certa; a recusa do presidente', () => {
    const ISS = 'https://api.dmsregem.com';
    const estado = 's'.repeat(43);
    expect(
      conferirVolta({ code: 'c'.repeat(43), state: estado, iss: ISS }, ISS),
    ).toEqual({
      tipo: 'codigo',
      estado,
      codigo: 'c'.repeat(43),
    });
    expect(
      conferirVolta(
        { code: 'c'.repeat(43), state: estado, iss: 'https://outro' },
        ISS,
      ),
    ).toMatchObject({
      tipo: 'invalida',
    });
    expect(
      conferirVolta({ code: 'c'.repeat(43), state: 'curto', iss: ISS }, ISS),
    ).toMatchObject({
      tipo: 'invalida',
    });
    expect(
      conferirVolta({ error: 'access_denied', state: estado, iss: ISS }, ISS),
    ).toEqual({
      tipo: 'recusa',
      estado,
      motivo: 'recusado',
    });
  });

  it('a troca: cada loja com a ligação e as três permissões; torta = nada é guardado', () => {
    const loja = (id: string, mudar: Record<string, unknown> = {}) => ({
      loja_id: id,
      loja_nome: `Loja ${id}`,
      ligacao: LIGACAO,
      prefixo: 'dms_lg_regem_aaaa',
      permissoes: [...PERMISSOES_DO_TOTEM],
      ...mudar,
    });
    const lojas = lojasDaTroca({ lojas: [loja('l1'), loja('l2')] });
    expect(lojas?.map((l) => [l.lojaId, l.nome])).toEqual([
      ['l1', 'Loja l1'],
      ['l2', 'Loja l2'],
    ]);
    expect(lojaEmUso(lojas!, 'l2').lojaId).toBe('l2');
    expect(lojaEmUso(lojas!, 'outra').lojaId).toBe('l1');
    expect(
      lojasDaTroca({
        lojas: [loja('l1', { permissoes: ['totem.catalogo.ler'] })],
      }),
    ).toBeNull();
    expect(
      lojasDaTroca({ lojas: [loja('l1', { ligacao: 'rgm_it_token' })] }),
    ).toBeNull();
    expect(lojasDaTroca({ lojas: [loja('l1'), loja('l1')] })).toBeNull();
    expect(lojasDaTroca({ lojas: [] })).toBeNull();
  });
});

describe('a ligação guardada', () => {
  it('cifrada na coluna, aberta só com a chave e a empresa certas; o resumo nunca leva a ligação', () => {
    const clique = {
      versao: 1,
      base: 'https://api.dmsregem.com/api/v1',
      emUso: 'l1',
      lojas: [
        {
          lojaId: 'l1',
          nome: 'Centro',
          prefixo: 'p',
          permissoes: [],
          ligacao: selarLigacao(DONO, 'l1', LIGACAO, CHAVE),
        },
      ],
      conectadoEm: '2026-11-15T10:00:00.000Z',
      conectadoPor: 'u1',
    };
    expect(JSON.stringify(clique)).not.toContain(LIGACAO);
    expect(ligacaoEmUso({ ...DONO, clique }, CHAVE)).toEqual({
      base: 'https://api.dmsregem.com/api/v1',
      ligacao: LIGACAO,
      lojaId: 'l1',
      nome: 'Centro',
    });
    // Outra empresa não abre a ligação desta (o contexto da cifra leva a empresa).
    expect(() =>
      ligacaoEmUso({ ...DONO, tenantId: 't2', clique }, CHAVE),
    ).toThrow();
    expect(resumoDoClique(clique)).toEqual({
      conectado: true,
      emUso: { id: 'l1', nome: 'Centro' },
      lojas: [{ id: 'l1', nome: 'Centro' }],
      conectadoEm: '2026-11-15T10:00:00.000Z',
    });
    expect(JSON.stringify(resumoDoClique(clique))).not.toContain('ligacao');
    expect(lerClique(null)).toBeNull();
    expect(ligacaoEmUso({ ...DONO, clique: null }, CHAVE)).toBeNull();
  });
});

describe('a chamada ao Regem pela ligação', () => {
  const antes = { ...process.env };
  beforeEach(() => {
    esquecerEsperasDoRegem();
    esquecerClienteDmsId();
    Object.assign(process.env, BASE_ENV);
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    for (const k of Object.keys(BASE_ENV)) {
      if (antes[k] === undefined) delete process.env[k];
      else process.env[k] = antes[k];
    }
    esquecerClienteDmsId();
  });

  const cfg = (extra: Partial<RegemConfig> = {}): RegemConfig => ({
    base: 'https://regem/api/v1',
    token: '',
    tokenIntegracao: null,
    ligacao: LIGACAO,
    integracaoId: 'integ-1',
    credencialRecusada: null,
    ...extra,
  });

  /** O DMS ID dá um token novo a cada pedido; o Regem responde a fila. */
  function servir(...doRegem: number[]) {
    let tokens = 0;
    const chamadas: { url: string; headers: Headers }[] = [];
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string, init?: RequestInit) => {
        chamadas.push({
          url: String(url),
          headers: new Headers(init?.headers),
        });
        if (String(url) === 'https://id.exemplo/oidc/token') {
          return new Response(
            JSON.stringify({
              access_token: `token-${++tokens}`,
              expires_in: 3600,
            }),
            {
              status: 200,
            },
          );
        }
        const status = doRegem.shift() ?? 500;
        return new Response(
          JSON.stringify(
            status === 200 ? { produtos: [] } : { detail: 'recusado' },
          ),
          {
            status,
          },
        );
      }),
    );
    return chamadas;
  }

  const resolver = () => ({
    marcarCredencialRecusada: vi.fn().mockResolvedValue(undefined),
  });

  it('manda o token do DMS ID e o DMS-Ligacao, sem X-Sync-Token', async () => {
    const chamadas = servir(200);
    const r = await chamarRegem(resolver(), cfg(), {
      caminho: '/sync/catalogo',
      metodo: 'GET',
      prazoMs: 5000,
      rotulo: 'catálogo',
    });
    expect(r.status).toBe(200);
    const doRegem = chamadas.filter((c) => c.url.startsWith('https://regem'));
    expect(doRegem[0]?.headers.get('authorization')).toBe('Bearer token-1');
    expect(doRegem[0]?.headers.get('dms-ligacao')).toBe(LIGACAO);
    expect(doRegem[0]?.headers.get('x-sync-token')).toBeNull();
  });

  it('o 401 pede outro token ao DMS ID e tenta uma vez mais; o segundo marca a recusa da ligação', async () => {
    servir(401, 200);
    const ok = await chamarRegem(resolver(), cfg(), {
      caminho: '/sync/catalogo',
      metodo: 'GET',
      prazoMs: 5000,
      rotulo: 'catálogo',
    });
    expect(ok.status).toBe(200);

    servir(401, 401);
    const r = resolver();
    const erro = await chamarRegem(r, cfg(), {
      caminho: '/sync/catalogo',
      metodo: 'GET',
      prazoMs: 5000,
      rotulo: 'catálogo',
    }).catch((e) => e);
    expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
    expect(erro.message).toContain('Conecte de novo pelo Regem');
    expect(r.marcarCredencialRecusada).toHaveBeenCalledTimes(1);
  });

  it('a recusa já marcada segura a chamada pela ligação (sem ir à rede)', async () => {
    const chamadas = servir(200);
    const erro = await chamarRegem(
      resolver(),
      cfg({ credencialRecusada: { status: 401, detalhe: 'x', em: '' } }),
      {
        caminho: '/vendas/externa-pdv',
        metodo: 'POST',
        prazoMs: 5000,
        rotulo: 'venda',
      },
    ).catch((e) => e);
    expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
    expect(chamadas).toHaveLength(0);
  });

  it('o texto da recusa diz o que fazer em cada via', () => {
    expect(mensagemDaRecusa(401, '', 'ligacao')).toContain(
      'Conecte de novo pelo Regem',
    );
    expect(mensagemDaRecusa(401, '', 'token')).toContain(
      'Emita outro token no Regem',
    );
  });
});
