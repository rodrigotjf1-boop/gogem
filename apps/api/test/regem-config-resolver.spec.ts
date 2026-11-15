import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import { selarLigacao } from '../src/integracoes/regem/clique-guardado';
import type { PrismaService } from '../src/prisma/prisma.service';

function make() {
  const prisma = { integracao: { findFirst: vi.fn() } };
  const resolver = new RegemConfigResolver(prisma as unknown as PrismaService);
  return { resolver, prisma };
}

const cfg = (base: string, token: string, ativo = true) => ({
  ativo,
  config: { apiBase: base, token },
});

describe('RegemConfigResolver — cascata loja → empresa (sem Regem padrão)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('usa o token DA LOJA quando há integração ativa da unidade', async () => {
    const { resolver, prisma } = make();
    // 1ª chamada (loja) responde; a de empresa nem é consultada.
    prisma.integracao.findFirst.mockResolvedValueOnce(
      cfg('https://loja', 'tok-loja'),
    );

    const out = await resolver.resolve({ unidadeId: 'u1' });
    // Sem token de integração guardado: vale o de sincronização (e nada de recusa).
    expect(out).toMatchObject({
      base: 'https://loja',
      token: 'tok-loja',
      tokenIntegracao: null,
      credencialRecusada: null,
    });
    expect(prisma.integracao.findFirst.mock.calls[0][0].where).toEqual({
      tipo: 'regem',
      unidadeId: 'u1',
    });
  });

  it('cai pra EMPRESA (unidadeId null) quando a loja não tem/está inativa', async () => {
    const { resolver, prisma } = make();
    prisma.integracao.findFirst
      .mockResolvedValueOnce(cfg('https://loja', 'x', false)) // loja inativa
      .mockResolvedValueOnce(cfg('https://empresa', 'tok-emp')); // empresa

    const out = await resolver.resolve({ unidadeId: 'u1' });
    expect(out).toMatchObject({ base: 'https://empresa', token: 'tok-emp' });
    expect(prisma.integracao.findFirst.mock.calls[1][0].where).toEqual({
      tipo: 'regem',
      unidadeId: null,
    });
  });

  it('sem unidade: vai direto ao nível empresa', async () => {
    const { resolver, prisma } = make();
    prisma.integracao.findFirst.mockResolvedValueOnce(
      cfg('https://empresa', 'tok-emp'),
    );

    const out = await resolver.resolve();
    expect(out).toMatchObject({ base: 'https://empresa', token: 'tok-emp' });
    expect(prisma.integracao.findFirst).toHaveBeenCalledTimes(1);
    expect(prisma.integracao.findFirst.mock.calls[0][0].where).toEqual({
      tipo: 'regem',
      unidadeId: null,
    });
  });

  // ERR-012 — o "Regem padrão" das envs mandava a venda da empresa SEM integração para o
  // Regem de OUTRA empresa (e baixava o cardápio dela), com resposta de sucesso.
  it('sem integração da empresa: ERRO — mesmo com as envs globais definidas', async () => {
    const { resolver, prisma } = make();
    prisma.integracao.findFirst.mockResolvedValue(null);
    process.env.REGEM_API_BASE = 'https://regem-do-piloto';
    process.env.REGEM_SYNC_TOKEN = 'TOKEN-DO-PILOTO';
    try {
      await expect(resolver.resolve({ unidadeId: 'u1' })).rejects.toThrow(
        /não configurada/i,
      );
    } finally {
      delete process.env.REGEM_API_BASE;
      delete process.env.REGEM_SYNC_TOKEN;
    }
  });

  it('nada configurado: lança erro acionável', async () => {
    const { resolver, prisma } = make();
    prisma.integracao.findFirst.mockResolvedValue(null);
    await expect(resolver.resolve()).rejects.toThrow(/não configurada/i);
  });
});

describe('RegemConfigResolver — a ligação do "Conectar pelo Regem"', () => {
  const CHAVE = Buffer.alloc(32, 9);
  const LIGACAO = `dms_lg_regem_${'c'.repeat(43)}_${'d'.repeat(6)}`;
  const antes = process.env.GOGEM_CHAVE_DOS_SEGREDOS;
  beforeEach(() => {
    process.env.GOGEM_CHAVE_DOS_SEGREDOS = CHAVE.toString('base64');
  });
  afterEach(() => {
    if (antes === undefined) delete process.env.GOGEM_CHAVE_DOS_SEGREDOS;
    else process.env.GOGEM_CHAVE_DOS_SEGREDOS = antes;
  });

  const linha = (config: Record<string, unknown>) => {
    const dono = { tenantId: 't1', unidadeId: null, tipo: 'regem' };
    return {
      id: 'integ-1',
      ...dono,
      ativo: true,
      config,
      ultimoTeste: null,
      clique: {
        versao: 1,
        base: 'https://api.dmsregem.com/api/v1',
        emUso: 'l1',
        lojas: [
          {
            lojaId: 'l1',
            nome: 'Centro',
            prefixo: 'p',
            permissoes: [],
            ligacao: selarLigacao(dono, 'l1', LIGACAO, CHAVE),
          },
        ],
        conectadoEm: '2026-11-15T10:00:00.000Z',
        conectadoPor: 'u1',
      },
    };
  };

  it('a ligação vence o token colado e vai à base do Regem que a emitiu, não ao apiBase colado antes', async () => {
    const { resolver, prisma } = make();
    // O endereço colado antes era outro (o servidor da loja, um ambiente de teste): a ligação só
    // vale no Regem que a emitiu, e mandá-la a outro lugar daria 401 e marcaria a recusa à toa.
    prisma.integracao.findFirst.mockResolvedValueOnce(
      linha({ apiBase: 'https://regem.da.loja/api/v1', token: 'tok-antigo' }),
    );

    const out = await resolver.resolve();
    expect(out).toMatchObject({
      base: 'https://api.dmsregem.com/api/v1',
      ligacao: LIGACAO,
      tokenIntegracao: null,
      credencialRecusada: null,
    });
  });

  it('sem token colado nem apiBase: a linha do clique vale sozinha', async () => {
    const { resolver, prisma } = make();
    prisma.integracao.findFirst.mockResolvedValueOnce(linha({}));

    const out = await resolver.resolve();
    expect(out).toMatchObject({
      base: 'https://api.dmsregem.com/api/v1',
      token: '',
      ligacao: LIGACAO,
    });
  });
});
