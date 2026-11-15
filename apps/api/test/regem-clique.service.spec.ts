import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createHash } from 'node:crypto';
import { ENV_CHAVE_DOS_SEGREDOS } from '../src/integracao/segredos';
import { esquecerClienteDmsId } from '../src/integracoes/regem/dms-id.cliente';
import { ligacaoEmUso } from '../src/integracoes/regem/clique-guardado';
import { RegemCliqueService } from '../src/integracoes/regem/regem-clique.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { RegemAvisosService } from '../src/integracoes/regem/regem-avisos.service';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';

/**
 * "CONECTAR PELO REGEM" no serviço (Hub DMS F6): o pedido empurrado, a volta conferida (iss e
 * state, uma vez só, de quem começou), a ligação de cada loja guardada cifrada na integração da
 * empresa, os avisos registrados de novo e a troca da loja em uso. O banco é um dublê em memória;
 * o DMS ID e a porta do Regem, dublês do `fetch`. Valores fictícios.
 */

const CHAVE = Buffer.alloc(32, 7);
const ENV = {
  GOGEM_REGEM_CLIQUE: 'true',
  GOGEM_REGEM_API_URL: 'https://regem.teste/api/v1',
  GOGEM_PAINEL_URL: 'https://painel.teste',
  DMS_ID_EMISSOR: 'https://id.teste/oidc',
  DMS_ID_APLICATIVO: 'app-gogem-de-teste',
  DMS_ID_SEGREDO: 'segredo-de-teste-123456',
  [ENV_CHAVE_DOS_SEGREDOS]: CHAVE.toString('base64'),
};
const ISS = 'https://regem.teste';
const ligacao = (n: string) => `dms_lg_regem_${n.repeat(43)}_${'b'.repeat(6)}`;
const QUEM = { userId: 'u1', tenantId: 't1', email: 'dono@brasa.exemplo' };

function bancoEmMemoria() {
  const pedidos: Record<string, any>[] = [];
  let integracao: Record<string, any> | null = null;
  const prisma = {
    tenant: { findUnique: vi.fn(async () => ({ nome: 'Brasa Burger' })) },
    regemCliquePedido: {
      create: vi.fn(async ({ data }: any) => {
        pedidos.push({ id: `p${pedidos.length + 1}`, usadoEm: null, ...data });
        return pedidos.at(-1);
      }),
      deleteMany: vi.fn(async () => ({ count: 0 })),
      updateMany: vi.fn(async ({ where, data }: any) => {
        const alvo = pedidos.filter(
          (p) =>
            p.estadoHash === where.estadoHash &&
            p.tenantId === where.tenantId &&
            p.usuarioId === where.usuarioId &&
            p.usadoEm === null &&
            p.venceEm > where.venceEm.gt,
        );
        for (const p of alvo) Object.assign(p, data);
        return { count: alvo.length };
      }),
      findUnique: vi.fn(
        async ({ where }: any) =>
          pedidos.find((p) => p.estadoHash === where.estadoHash) ?? null,
      ),
    },
    integracao: {
      findFirst: vi.fn(async () => integracao),
      create: vi.fn(async ({ data }: any) => {
        integracao = {
          id: 'integ-1',
          config: {},
          ultimoTeste: null,
          avisos: null,
          ...data,
        };
        return integracao;
      }),
      update: vi.fn(async ({ data }: any) => {
        integracao = { ...integracao!, ...data };
        return integracao;
      }),
    },
  };
  return {
    prisma,
    pedidos,
    linha: () => integracao,
    porLinha: (l: Record<string, any>) => (integracao = l),
  };
}

/** A rede: o DMS ID dá um token; a porta do Regem responde pelo que o teste mandar. */
function rede(regem: { pedido?: () => Response; token?: () => Response }) {
  const chamadas: { url: string; corpo: any; headers: Headers }[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init?: RequestInit) => {
      const corpo =
        typeof init?.body === 'string' && init.body.startsWith('{')
          ? JSON.parse(init.body)
          : init?.body;
      chamadas.push({
        url: String(url),
        corpo,
        headers: new Headers(init?.headers),
      });
      if (String(url) === 'https://id.teste/oidc/token') {
        return new Response(
          JSON.stringify({ access_token: 'token-do-dms-id', expires_in: 3600 }),
          { status: 200 },
        );
      }
      if (
        String(url) ===
        'https://regem.teste/api/v1/integracao/autorizacao/pedido'
      ) {
        return (
          regem.pedido?.() ??
          new Response(
            JSON.stringify({
              request_uri: `urn:ietf:params:oauth:request_uri:rgm_${'n'.repeat(43)}`,
            }),
            {
              status: 201,
            },
          )
        );
      }
      if (
        String(url) ===
        'https://regem.teste/api/v1/integracao/autorizacao/token'
      ) {
        return regem.token?.() ?? new Response('{}', { status: 500 });
      }
      throw new Error(`chamada inesperada: ${url}`);
    }),
  );
  return chamadas;
}

const troca = (...lojas: string[]) =>
  new Response(
    JSON.stringify({
      lojas: lojas.map((id, i) => ({
        loja_id: id,
        loja_nome: `Loja ${id}`,
        ligacao: ligacao(String.fromCharCode(97 + i)),
        prefixo: 'dms_lg_regem_x',
        permissoes: [
          'totem.catalogo.ler',
          'totem.produtos.pausar',
          'totem.vendas.lancar',
        ],
      })),
    }),
    { status: 200 },
  );

describe('RegemCliqueService — "Conectar pelo Regem"', () => {
  const antes = { ...process.env };
  let banco: ReturnType<typeof bancoEmMemoria>;
  let servico: RegemCliqueService;
  let avisos: { garantirRegistro: ReturnType<typeof vi.fn> };
  let resolver: { resolve: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    esquecerClienteDmsId();
    Object.assign(process.env, ENV);
    banco = bancoEmMemoria();
    avisos = {
      garantirRegistro: vi.fn(async () => ({
        detalhe: 'Avisos do Regem: ligados (assinados).',
      })),
    };
    resolver = {
      resolve: vi.fn(async () => ({
        base: 'https://regem.teste/api/v1',
        token: '',
        ligacao: 'x',
        integracaoId: 'integ-1',
      })),
    };
    servico = new RegemCliqueService(
      banco.prisma as unknown as PrismaService,
      resolver as unknown as RegemConfigResolver,
      avisos as unknown as RegemAvisosService,
    );
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    for (const k of Object.keys(ENV)) {
      if (antes[k] === undefined) delete process.env[k];
      else process.env[k] = antes[k];
    }
    esquecerClienteDmsId();
  });

  it('desligado no servidor: o botão não aparece e as rotas recusam com 503 (nunca 401)', async () => {
    delete process.env.GOGEM_REGEM_CLIQUE;
    esquecerClienteDmsId();
    expect(servico.disponivel).toBe(false);
    await expect(servico.iniciar(QUEM)).rejects.toMatchObject({ status: 503 });
  });

  it('o início empurra o pedido com o token do DMS ID e guarda só o resumo do state e o verificador cifrado', async () => {
    const chamadas = rede({});
    expect(servico.disponivel).toBe(true);
    const { url } = await servico.iniciar(QUEM);
    const pagina = new URL(url);
    expect(pagina.origin + pagina.pathname).toBe(
      'https://app.dmsregem.com/integracoes/autorizar',
    );
    expect(pagina.searchParams.get('client_id')).toBe('app-gogem-de-teste');
    const pedido = chamadas.find((c) => c.url.endsWith('/autorizacao/pedido'))!;
    expect(pedido.headers.get('authorization')).toBe('Bearer token-do-dms-id');
    expect(pedido.corpo).toMatchObject({
      redirect_uri: 'https://painel.teste/integracoes/regem/volta',
      scope: 'totem.catalogo.ler totem.produtos.pausar totem.vendas.lancar',
      conta_nome: 'Brasa Burger',
      conta_email: 'dono@brasa.exemplo',
    });
    expect(pedido.corpo).not.toHaveProperty('conta_cnpj');
    const [guardado] = banco.pedidos;
    expect(guardado.estadoHash).toBe(
      createHash('sha256').update(pedido.corpo.state, 'utf8').digest('hex'),
    );
    expect(JSON.stringify(guardado)).not.toContain(pedido.corpo.state);
    expect(guardado.verificadorCifrado.startsWith('v1.')).toBe(true);
  });

  it('o Regem recusa o pedido: a conta lê uma frase, nada é guardado', async () => {
    rede({
      pedido: () =>
        new Response(
          JSON.stringify({
            detail: 'redirect_uri não é um endereço de volta cadastrado',
          }),
          { status: 400 },
        ),
    });
    await expect(servico.iniciar(QUEM)).rejects.toMatchObject({ status: 503 });
    expect(banco.pedidos).toHaveLength(0);
  });

  it('a volta: iss errado não vale; com o código, guarda a ligação de cada loja cifrada, a matriz em uso, e religa os avisos', async () => {
    const chamadas = rede({ token: () => troca('l1', 'l2') });
    await servico.iniciar(QUEM);
    const pedido = chamadas.find((c) =>
      c.url.endsWith('/autorizacao/pedido'),
    )!.corpo;
    await expect(
      servico.concluir(QUEM, {
        code: 'c'.repeat(43),
        state: pedido.state,
        iss: 'https://outro',
      }),
    ).rejects.toMatchObject({
      status: 400,
    });

    const r = await servico.concluir(QUEM, {
      code: 'c'.repeat(43),
      state: pedido.state,
      iss: ISS,
    });
    expect(r).toMatchObject({
      situacao: 'conectado',
      clique: {
        disponivel: true,
        conectado: true,
        emUso: { id: 'l1', nome: 'Loja l1' },
      },
      avisos: 'Avisos do Regem: ligados (assinados).',
    });
    // A troca levou o verificador do PKCE e a volta cadastrada.
    const t = chamadas.find((c) => c.url.endsWith('/autorizacao/token'))!.corpo;
    expect(t).toMatchObject({
      grant_type: 'authorization_code',
      redirect_uri: 'https://painel.teste/integracoes/regem/volta',
    });
    expect(
      createHash('sha256').update(t.code_verifier, 'ascii').digest('base64url'),
    ).toBe(pedido.code_challenge);
    // Guardada cifrada na integração da empresa (nasceu ativa, com a base do Regem).
    const linha = banco.linha()!;
    expect(linha).toMatchObject({
      tenantId: 't1',
      unidadeId: null,
      tipo: 'regem',
      ativo: true,
      config: { apiBase: 'https://regem.teste/api/v1' },
    });
    expect(JSON.stringify(linha.clique)).not.toContain(ligacao('a'));
    expect(ligacaoEmUso(linha as any, CHAVE)?.ligacao).toBe(ligacao('a'));
    expect(avisos.garantirRegistro).toHaveBeenCalledWith(expect.anything(), {
      forcar: true,
    });
    // O mesmo pedido não vale de novo.
    await expect(
      servico.concluir(QUEM, {
        code: 'c'.repeat(43),
        state: pedido.state,
        iss: ISS,
      }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('o pedido de outra pessoa não vale; o presidente recusou: nada muda', async () => {
    const chamadas = rede({});
    await servico.iniciar(QUEM);
    const pedido = chamadas.find((c) =>
      c.url.endsWith('/autorizacao/pedido'),
    )!.corpo;
    await expect(
      servico.concluir(
        { ...QUEM, userId: 'outra-pessoa' },
        { code: 'c'.repeat(43), state: pedido.state, iss: ISS },
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(
      await servico.concluir(QUEM, {
        error: 'access_denied',
        state: pedido.state,
        iss: ISS,
      }),
    ).toEqual({ situacao: 'recusado' });
    expect(banco.linha()).toBeNull();
  });

  it('a integração que já tinha o token colado: a ligação entra, a recusa marcada e o registro dos avisos são limpos', async () => {
    banco.porLinha({
      id: 'integ-1',
      tenantId: 't1',
      unidadeId: null,
      tipo: 'regem',
      ativo: true,
      config: { apiBase: 'https://regem.teste/api/v1', token: 'v1.antigo' },
      ultimoTeste: { ok: false, credencialRecusada: { status: 401 } },
      avisos: { registradoEm: '2026-10-20T00:00:00.000Z' },
      clique: null,
    });
    const chamadas = rede({ token: () => troca('l1') });
    await servico.iniciar(QUEM);
    const pedido = chamadas.find((c) =>
      c.url.endsWith('/autorizacao/pedido'),
    )!.corpo;
    await servico.concluir(QUEM, {
      code: 'c'.repeat(43),
      state: pedido.state,
      iss: ISS,
    });
    const linha = banco.linha()!;
    expect(linha.config).toEqual({
      apiBase: 'https://regem.teste/api/v1',
      token: 'v1.antigo',
    });
    expect(String(linha.ultimoTeste)).toBe('Prisma.DbNull');
    expect(String(linha.avisos)).toBe('Prisma.DbNull');
    expect(ligacaoEmUso(linha as any, CHAVE)?.lojaId).toBe('l1');
  });

  it('a troca torta ou recusada: nada é guardado', async () => {
    const chamadas = rede({
      token: () =>
        new Response(
          JSON.stringify({ lojas: [{ loja_id: 'l1', ligacao: 'rgm_it_x' }] }),
          { status: 200 },
        ),
    });
    await servico.iniciar(QUEM);
    const pedido = chamadas.find((c) =>
      c.url.endsWith('/autorizacao/pedido'),
    )!.corpo;
    await expect(
      servico.concluir(QUEM, {
        code: 'c'.repeat(43),
        state: pedido.state,
        iss: ISS,
      }),
    ).rejects.toMatchObject({ status: 503 });
    expect(banco.linha()).toBeNull();
  });

  it('trocar a loja em uso: só entre as ligadas, e os avisos registram de novo pela loja nova', async () => {
    const chamadas = rede({ token: () => troca('l1', 'l2') });
    await servico.iniciar(QUEM);
    const pedido = chamadas.find((c) =>
      c.url.endsWith('/autorizacao/pedido'),
    )!.corpo;
    await servico.concluir(QUEM, {
      code: 'c'.repeat(43),
      state: pedido.state,
      iss: ISS,
    });
    avisos.garantirRegistro.mockClear();
    expect(await servico.escolher('l2')).toMatchObject({
      emUso: { id: 'l2', nome: 'Loja l2' },
    });
    expect(ligacaoEmUso(banco.linha() as any, CHAVE)?.ligacao).toBe(
      ligacao('b'),
    );
    expect(avisos.garantirRegistro).toHaveBeenCalledTimes(1);
    await expect(servico.escolher('outra')).rejects.toMatchObject({
      status: 400,
    });
  });
});
