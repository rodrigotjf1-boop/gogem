import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createCipheriv } from 'node:crypto';
import { cifrar, decifrar, ehCifrado, lerChave } from '../src/common/cifra';
import { CONECTORES } from '../src/integracao/conectores';
import {
  ENV_CHAVE_DOS_SEGREDOS,
  SegredoIlegivelException,
  SemChaveDosSegredosException,
  buscaDoSegredo,
  contextoDoSegredo,
  segredoDa,
  selarConfig,
  type DonoDoSegredo,
} from '../src/integracao/segredos';
import { SegredosMigracao } from '../src/integracao/segredos.migracao';
import { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import { PspResolver } from '../src/pagamentos/psp/psp-resolver';
import { MercadoPagoPspGateway } from '../src/pagamentos/psp/mercadopago-psp.gateway';
import type { PrismaService } from '../src/prisma/prisma.service';

// Chaves de teste de baixa entropia (32 bytes iguais): só valem aqui.
const CHAVE = Buffer.alloc(32, 7);
const OUTRA_CHAVE = Buffer.alloc(32, 9);
const DONO: DonoDoSegredo = { tenantId: 't1', unidadeId: null, tipo: 'regem' };

const linhaCifrada = (
  dono: DonoDoSegredo,
  campo: string,
  claro: string,
  extra: Record<string, unknown> = {},
) => ({
  ...dono,
  config: {
    ...extra,
    [campo]: cifrar(claro, CHAVE, contextoDoSegredo(dono, campo)),
  },
});

describe('cifra (AES-256-GCM, formato v1)', () => {
  it('ida e volta com a mesma chave e o mesmo contexto', () => {
    const c = cifrar('valor-de-teste', CHAVE, 'ctx');
    expect(ehCifrado(c)).toBe(true);
    expect(c).not.toContain('valor-de-teste');
    expect(decifrar(c, CHAVE, 'ctx')).toBe('valor-de-teste');
  });

  it('o mesmo valor cifrado duas vezes dá textos diferentes', () => {
    expect(cifrar('x', CHAVE, 'ctx')).not.toBe(cifrar('x', CHAVE, 'ctx'));
  });

  it('outra chave, outro contexto ou texto adulterado → null', () => {
    const c = cifrar('valor-de-teste', CHAVE, 'ctx');
    expect(decifrar(c, OUTRA_CHAVE, 'ctx')).toBeNull();
    expect(decifrar(c, CHAVE, 'outro-ctx')).toBeNull();
    const [v, n, m, corpo] = c.split('.');
    const trocado = corpo!.startsWith('A')
      ? `B${corpo!.slice(1)}`
      : `A${corpo!.slice(1)}`;
    expect(decifrar([v, n, m, trocado].join('.'), CHAVE, 'ctx')).toBeNull();
    expect(decifrar('lixo', CHAVE, 'ctx')).toBeNull();
  });

  it('marca de autenticação curta é recusada (não aceita 4 bytes)', () => {
    const numero = Buffer.alloc(12, 1);
    const c = createCipheriv('aes-256-gcm', CHAVE, numero, {
      authTagLength: 4,
    });
    c.setAAD(Buffer.from('ctx'));
    const corpo = Buffer.concat([c.update('x', 'utf8'), c.final()]);
    const curto = [
      'v1',
      numero.toString('base64url'),
      c.getAuthTag().toString('base64url'),
      corpo.toString('base64url'),
    ].join('.');
    expect(decifrar(curto, CHAVE, 'ctx')).toBeNull();
  });

  it('lerChave aceita só 32 bytes em base64', () => {
    expect(lerChave(CHAVE.toString('base64'))?.equals(CHAVE)).toBe(true);
    expect(lerChave(CHAVE.toString('base64url'))?.equals(CHAVE)).toBe(true);
    expect(lerChave(Buffer.alloc(16, 7).toString('base64'))).toBeNull();
    expect(lerChave('não é base64!')).toBeNull();
    expect(lerChave(undefined)).toBeNull();
  });
});

describe('segredoDa — leitura de um campo-segredo', () => {
  it('abre o valor cifrado da própria linha', () => {
    const linha = linhaCifrada(DONO, 'token', 'token-de-teste');
    expect(segredoDa(linha, 'token', CHAVE)).toBe('token-de-teste');
  });

  it('valor antigo em claro passa como está (antes da migração)', () => {
    expect(
      segredoDa({ ...DONO, config: { token: ' antigo ' } }, 'token', null),
    ).toBe('antigo');
  });

  it('linha ou campo ausente → vazio', () => {
    expect(segredoDa(null, 'token', CHAVE)).toBe('');
    expect(segredoDa({ ...DONO, config: {} }, 'token', CHAVE)).toBe('');
  });

  it('cifrado sem a chave → 503, não "sem integração"', () => {
    const linha = linhaCifrada(DONO, 'token', 'token-de-teste');
    expect(() => segredoDa(linha, 'token', null)).toThrow(
      SegredoIlegivelException,
    );
  });

  it('texto copiado para a linha de outra empresa não abre', () => {
    const linha = linhaCifrada(DONO, 'token', 'token-de-teste');
    const copia = { ...linha, tenantId: 't2' };
    expect(() => segredoDa(copia, 'token', CHAVE)).toThrow(
      SegredoIlegivelException,
    );
  });

  it('texto de um campo não abre como outro campo', () => {
    const linha = linhaCifrada(DONO, 'token', 'token-de-teste');
    const trocado = { ...linha, config: { accessToken: linha.config.token } };
    expect(() => segredoDa(trocado, 'accessToken', CHAVE)).toThrow(
      SegredoIlegivelException,
    );
  });
});

describe('selarConfig — o que vai para o banco', () => {
  const regem = CONECTORES.regem!;

  it('cifra o segredo em claro, deixa o resto e calcula o resumo', () => {
    const out = selarConfig(
      regem,
      DONO,
      { apiBase: 'https://a', token: 'token-de-teste' },
      null,
      new Set(['token']),
      CHAVE,
    );
    expect(out.config.apiBase).toBe('https://a');
    expect(ehCifrado(out.config.token)).toBe(true);
    expect(out.segredoBusca).toBe(buscaDoSegredo('token-de-teste'));
    expect(out.cifrados).toBe(1);
    expect(segredoDa({ ...DONO, config: out.config }, 'token', CHAVE)).toBe(
      'token-de-teste',
    );
  });

  it('já cifrado e com resumo: não muda nada', () => {
    const linha = linhaCifrada(DONO, 'token', 'token-de-teste');
    const busca = buscaDoSegredo('token-de-teste');
    const out = selarConfig(regem, DONO, linha.config, busca, new Set(), CHAVE);
    expect(out.config).toEqual(linha.config);
    expect(out.segredoBusca).toBe(busca);
    expect(out.cifrados).toBe(0);
  });

  it('já cifrado sem resumo: calcula o resumo abrindo com a chave', () => {
    const linha = linhaCifrada(DONO, 'token', 'token-de-teste');
    const out = selarConfig(regem, DONO, linha.config, null, new Set(), CHAVE);
    expect(out.segredoBusca).toBe(buscaDoSegredo('token-de-teste'));
    expect(out.cifrados).toBe(0);
  });

  it('sem chave: segredo NOVO é recusado', () => {
    expect(() =>
      selarConfig(
        regem,
        DONO,
        { token: 'token-de-teste' },
        null,
        new Set(['token']),
        null,
      ),
    ).toThrow(SemChaveDosSegredosException);
  });

  it('sem chave: segredo antigo fica em claro, mas o resumo é preenchido', () => {
    const out = selarConfig(
      regem,
      DONO,
      { token: 'token-de-teste' },
      null,
      new Set(),
      null,
    );
    expect(out.config.token).toBe('token-de-teste');
    expect(out.segredoBusca).toBe(buscaDoSegredo('token-de-teste'));
    expect(out.emClaro).toBe(1);
  });
});

describe('SegredosMigracao — cifra os antigos ao subir', () => {
  function makeMigracao(rows: any[]) {
    const store = rows.map((r) => ({ ...r, config: { ...r.config } }));
    const prisma = {
      integracao: {
        findMany: vi
          .fn()
          .mockImplementation(async () =>
            store.map((r) => ({ ...r, config: { ...r.config } })),
          ),
        updateMany: vi.fn().mockImplementation(async ({ where, data }: any) => {
          const row = store.find(
            (r) =>
              r.id === where.id &&
              r.segredoBusca === where.segredoBusca &&
              JSON.stringify(r.config) === JSON.stringify(where.config.equals),
          );
          if (!row) return { count: 0 };
          Object.assign(row, data);
          return { count: 1 };
        }),
      },
    };
    const migracao = new SegredosMigracao(prisma as unknown as PrismaService);
    return { migracao, prisma, store };
  }

  const antigas = () => [
    {
      id: 'r1',
      tenantId: 't1',
      unidadeId: null,
      tipo: 'regem',
      config: {
        apiBase: 'https://a',
        token: 'token-antigo-1',
        ignorados: ['7'],
      },
      segredoBusca: null,
    },
    {
      id: 'm1',
      tenantId: 't1',
      unidadeId: 'u1',
      tipo: 'mercadopago',
      config: { accessToken: 'mp-antigo', deviceId: 'POINT-1' },
      segredoBusca: null,
    },
    {
      id: 'x1',
      tenantId: 't1',
      unidadeId: null,
      tipo: 'desconhecido',
      config: { token: 'fica' },
      segredoBusca: null,
    },
  ];

  it('cifra os segredos em claro, preenche o resumo e mantém o resto', async () => {
    const { migracao, store } = makeMigracao(antigas());
    const r = await migracao.migrar(CHAVE);
    expect(r).toMatchObject({
      gravadas: 2,
      cifrados: 2,
      emClaro: 0,
      adiadas: 0,
    });

    const [regem, mp, outro] = store;
    expect(ehCifrado(regem.config.token)).toBe(true);
    expect(regem.config.ignorados).toEqual(['7']);
    expect(regem.segredoBusca).toBe(buscaDoSegredo('token-antigo-1'));
    expect(segredoDa(regem, 'token', CHAVE)).toBe('token-antigo-1');
    expect(segredoDa(mp, 'accessToken', CHAVE)).toBe('mp-antigo');
    expect(mp.config.deviceId).toBe('POINT-1');
    expect(mp.segredoBusca).toBeNull();
    expect(outro.config.token).toBe('fica'); // conector desconhecido: intocado
  });

  it('é idempotente: a segunda passada não grava nada', async () => {
    const { migracao, prisma, store } = makeMigracao(antigas());
    await migracao.migrar(CHAVE);
    const depois = JSON.stringify(store);
    prisma.integracao.updateMany.mockClear();
    const r = await migracao.migrar(CHAVE);
    expect(r.gravadas).toBe(0);
    expect(prisma.integracao.updateMany).not.toHaveBeenCalled();
    expect(JSON.stringify(store)).toBe(depois);
  });

  it('grava só se a linha não mudou desde a leitura', async () => {
    const { migracao, prisma, store } = makeMigracao(antigas().slice(0, 1));
    // O lojista salvou entre a leitura e a gravação.
    prisma.integracao.findMany.mockImplementationOnce(async () => {
      const lido = store.map((r) => ({ ...r, config: { ...r.config } }));
      store[0].config = { ...store[0].config, apiBase: 'https://nova' };
      return lido;
    });
    const r = await migracao.migrar(CHAVE);
    expect(r).toMatchObject({ gravadas: 0, adiadas: 1 });
    expect(store[0].config.token).toBe('token-antigo-1');
    expect(store[0].config.apiBase).toBe('https://nova');
  });

  it('sem chave: só preenche o resumo do token do Regem', async () => {
    const { migracao, store } = makeMigracao(antigas());
    const r = await migracao.migrar(null);
    expect(r).toMatchObject({ gravadas: 1, cifrados: 0, emClaro: 2 });
    expect(store[0].config.token).toBe('token-antigo-1');
    expect(store[0].segredoBusca).toBe(buscaDoSegredo('token-antigo-1'));
    expect(store[1].config.accessToken).toBe('mp-antigo');
  });

  it('falha do banco não rejeita (a subida segue)', async () => {
    const { migracao, prisma } = makeMigracao([]);
    prisma.integracao.findMany.mockRejectedValue(new Error('banco fora'));
    await expect(migracao.migrar(CHAVE)).resolves.toMatchObject({
      gravadas: 0,
    });
  });
});

describe('leitores abrem o segredo cifrado', () => {
  beforeEach(() => {
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE.toString('base64');
  });
  afterEach(() => {
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
    vi.unstubAllGlobals();
  });

  it('RegemConfigResolver devolve o token em claro para chamar o Regem', async () => {
    const linha = {
      ...linhaCifrada(DONO, 'token', 'token-de-teste', {
        apiBase: 'https://r',
      }),
      ativo: true,
    };
    const prisma = {
      integracao: { findFirst: vi.fn().mockResolvedValue(linha) },
    };
    const resolver = new RegemConfigResolver(
      prisma as unknown as PrismaService,
    );
    await expect(resolver.resolve()).resolves.toMatchObject({
      base: 'https://r',
      token: 'token-de-teste',
      tokenIntegracao: null,
    });
  });

  it('PspResolver usa o access token aberto da loja', async () => {
    const dono = { tenantId: 't1', unidadeId: null, tipo: 'mercadopago' };
    const linha = {
      ...linhaCifrada(dono, 'accessToken', 'mp-de-teste', {
        deviceId: 'POINT-1',
      }),
      ativo: true,
    };
    const prisma = {
      integracao: { findFirst: vi.fn().mockResolvedValue(linha) },
    };
    const psp = new PspResolver(prisma as unknown as PrismaService);
    expect(await psp.resolver()).toBeInstanceOf(MercadoPagoPspGateway);
    expect(await psp.tokenMercadoPago()).toBe('mp-de-teste');
    expect(await psp.resolverPoint()).not.toBeNull();
  });

  it('PspResolver com segredo que não abre: erro, nunca o sandbox', async () => {
    const dono = { tenantId: 't1', unidadeId: null, tipo: 'mercadopago' };
    const linha = {
      ...linhaCifrada(dono, 'accessToken', 'mp-de-teste'),
      ativo: true,
    };
    process.env[ENV_CHAVE_DOS_SEGREDOS] = OUTRA_CHAVE.toString('base64');
    const prisma = {
      integracao: { findFirst: vi.fn().mockResolvedValue(linha) },
    };
    const psp = new PspResolver(prisma as unknown as PrismaService);
    await expect(psp.resolver()).rejects.toBeInstanceOf(
      SegredoIlegivelException,
    );
  });
});
