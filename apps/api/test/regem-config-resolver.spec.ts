import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { ConfigService } from '@nestjs/config';

function make() {
  const prisma = { integracao: { findFirst: vi.fn() } };
  const config = { get: vi.fn().mockReturnValue(undefined) };
  const resolver = new RegemConfigResolver(
    prisma as unknown as PrismaService,
    config as unknown as ConfigService,
  );
  return { resolver, prisma, config };
}

const cfg = (base: string, token: string, ativo = true) => ({
  ativo,
  config: { apiBase: base, token },
});

describe('RegemConfigResolver — cascata loja → empresa → env', () => {
  beforeEach(() => vi.clearAllMocks());

  it('usa o token DA LOJA quando há integração ativa da unidade', async () => {
    const { resolver, prisma } = make();
    // 1ª chamada (loja) responde; a de empresa nem é consultada.
    prisma.integracao.findFirst.mockResolvedValueOnce(
      cfg('https://loja', 'tok-loja'),
    );

    const out = await resolver.resolve({ unidadeId: 'u1' });
    expect(out).toEqual({ base: 'https://loja', token: 'tok-loja' });
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
    expect(out).toEqual({ base: 'https://empresa', token: 'tok-emp' });
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
    expect(out).toEqual({ base: 'https://empresa', token: 'tok-emp' });
    expect(prisma.integracao.findFirst).toHaveBeenCalledTimes(1);
    expect(prisma.integracao.findFirst.mock.calls[0][0].where).toEqual({
      tipo: 'regem',
      unidadeId: null,
    });
  });

  it('sem config no banco: cai no fallback das envs', async () => {
    const { resolver, prisma, config } = make();
    prisma.integracao.findFirst.mockResolvedValue(null);
    config.get.mockImplementation((k: string) =>
      k === 'REGEM_API_BASE' ? 'https://env' : 'tok-env',
    );

    const out = await resolver.resolve({ unidadeId: 'u1' });
    expect(out).toEqual({ base: 'https://env', token: 'tok-env' });
  });

  it('nada configurado: lança erro acionável', async () => {
    const { resolver, prisma } = make();
    prisma.integracao.findFirst.mockResolvedValue(null);
    await expect(resolver.resolve()).rejects.toThrow(/não configurada/i);
  });
});
