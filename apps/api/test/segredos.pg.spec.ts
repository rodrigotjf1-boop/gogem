import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { TenantContext } from '../src/tenant/tenant-context';
import { IntegracaoService } from '../src/integracao/integracao.service';
import { SegredosMigracao } from '../src/integracao/segredos.migracao';
import {
  ENV_CHAVE_DOS_SEGREDOS,
  buscaDoSegredo,
} from '../src/integracao/segredos';
import { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import { RegemInboundService } from '../src/integracoes/regem/regem-inbound.service';
import { RegemAvisosService } from '../src/integracoes/regem/regem-avisos.service';

/**
 * Prova contra um Postgres DE VERDADE (opt-in): o filtro por resumo, o `OR` da
 * linha antiga e a gravação condicional por `config` (jsonb) dependem do banco.
 * Rodar num banco DESCARTÁVEL já migrado (`prisma migrate deploy`):
 *   SEGREDOS_PG_URL=postgresql://…/banco_descartavel?schema=public npx vitest run test/segredos.pg.spec.ts
 * Apaga as integrações e os tenants "cifra-…" desse banco.
 */
const URL = process.env.SEGREDOS_PG_URL;
const CHAVE = Buffer.alloc(32, 7); // baixa entropia: só vale aqui

describe.skipIf(!URL)('segredos das integrações — Postgres real', () => {
  let prisma: PrismaService;
  let tA = '';
  let tB = '';
  // Callback async: com o síncrono a consulta roda fora do contexto (ERR-031).
  const sistema = <T>(fn: () => Promise<T>) =>
    TenantContext.runAsSystem(async () => {
      const r = await fn();
      return r;
    });

  const inbound = () =>
    new RegemInboundService(
      prisma,
      {
        sincronizarLinkados: vi.fn().mockResolvedValue({ alterados: 0 }),
      } as any,
      { publicar: vi.fn() } as any,
      { cancelarPorChave: vi.fn() } as any,
    );

  beforeAll(async () => {
    process.env.DATABASE_URL = URL;
    prisma = new PrismaService();
    await prisma.$connect();
    await sistema(async () => {
      await prisma.integracao.deleteMany({});
      await prisma.tenant.deleteMany({
        where: { nome: { startsWith: 'cifra-' } },
      });
      tA = (await prisma.tenant.create({ data: { nome: 'cifra-a' } })).id;
      tB = (await prisma.tenant.create({ data: { nome: 'cifra-b' } })).id;
      // Linhas como estão hoje em produção: segredos em claro, sem resumo.
      await prisma.integracao.createMany({
        data: [
          {
            tenantId: tA,
            tipo: 'regem',
            ativo: true,
            config: {
              apiBase: 'https://a',
              token: 'token-antigo-a',
              ignorados: ['7'],
            },
          },
          {
            tenantId: tB,
            tipo: 'regem',
            ativo: true,
            config: { apiBase: 'https://b', token: 'token-antigo-b' },
          },
          {
            tenantId: tA,
            tipo: 'mercadopago',
            ativo: true,
            config: { accessToken: 'mp-antigo-a' },
          },
        ],
      });
    });
  });

  afterAll(async () => {
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
    await prisma?.$disconnect();
  });

  it('antes da migração: a entrada do Regem acha a empresa pelo valor em claro', async () => {
    await expect(inbound().publicar('token-antigo-b')).resolves.toEqual({
      alterados: 0,
    });
  });

  it('a migração cifra no banco e preenche o resumo', async () => {
    const r = await new SegredosMigracao(prisma).migrar(CHAVE);
    expect(r).toMatchObject({ gravadas: 3, cifrados: 3, adiadas: 0 });

    const linhas = await sistema(() =>
      prisma.integracao.findMany({ orderBy: { tipo: 'asc' } }),
    );
    const texto = JSON.stringify(linhas.map((l) => l.config));
    for (const claro of ['token-antigo-a', 'token-antigo-b', 'mp-antigo-a']) {
      expect(texto).not.toContain(claro);
    }
    for (const l of linhas) {
      const cfg = l.config as Record<string, string>;
      expect(cfg.token ?? cfg.accessToken).toMatch(/^v1\./);
    }
    const regemA = linhas.find((l) => l.tenantId === tA && l.tipo === 'regem')!;
    expect(regemA.segredoBusca).toBe(buscaDoSegredo('token-antigo-a'));
    expect((regemA.config as any).ignorados).toEqual(['7']);

    // Segunda passada: nada a fazer.
    const de_novo = await new SegredosMigracao(prisma).migrar(CHAVE);
    expect(de_novo).toMatchObject({ gravadas: 0, cifrados: 0, adiadas: 0 });
  });

  it('depois: a entrada do Regem acha cada empresa pelo resumo do token', async () => {
    const svc = inbound();
    await expect(svc.publicar('token-antigo-a')).resolves.toEqual({
      alterados: 0,
    });
    await expect(svc.publicar('token-antigo-b')).resolves.toEqual({
      alterados: 0,
    });
    await expect(svc.publicar('token-errado')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    // O texto cifrado também não serve de token.
    const cifrado = await sistema(async () => {
      const l = await prisma.integracao.findFirst({
        where: { tenantId: tA, tipo: 'regem' },
      });
      return (l!.config as Record<string, string>).token!;
    });
    await expect(svc.publicar(cifrado)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('a venda do totem recebe o token em claro para chamar o Regem', async () => {
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE.toString('base64');
    const resolver = new RegemConfigResolver(prisma);
    await expect(
      TenantContext.run({ tenantId: tA }, () => resolver.resolve()),
    ).resolves.toMatchObject({ base: 'https://a', token: 'token-antigo-a' });
  });

  it('token novo salvo pelo painel vai cifrado e a entrada acha por ele', async () => {
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE.toString('base64');
    const svc = new IntegracaoService(
      prisma,
      new RegemConfigResolver(prisma),
      {} as any,
      {} as any,
      { registrar: vi.fn() } as any,
      new RegemAvisosService(prisma, new RegemConfigResolver(prisma)),
    );
    await TenantContext.run({ tenantId: tB }, () =>
      svc.upsert('regem', { config: { token: 'token-novo-b' } }),
    );
    const linha = await sistema(() =>
      prisma.integracao.findFirst({ where: { tenantId: tB, tipo: 'regem' } }),
    );
    expect(JSON.stringify(linha!.config)).not.toContain('token-novo-b');
    expect(linha!.segredoBusca).toBe(buscaDoSegredo('token-novo-b'));
    await expect(inbound().publicar('token-novo-b')).resolves.toEqual({
      alterados: 0,
    });
    await expect(inbound().publicar('token-antigo-b')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('gravação condicional: jsonb igual em outra ordem casa; diferente não', async () => {
    const linha = await sistema(() =>
      prisma.integracao.findFirst({
        where: { tenantId: tA, tipo: 'mercadopago' },
      }),
    );
    const cfg = linha!.config as Record<string, string>;
    const invertido = Object.fromEntries(
      Object.entries({ ...cfg, z: '1' }).reverse(),
    );
    await sistema(() =>
      prisma.integracao.update({
        where: { id: linha!.id },
        data: { config: { ...cfg, z: '1' } },
      }),
    );
    const igual = await sistema(() =>
      prisma.integracao.updateMany({
        where: { id: linha!.id, config: { equals: invertido } },
        data: { nome: 'casou' },
      }),
    );
    const diferente = await sistema(() =>
      prisma.integracao.updateMany({
        where: { id: linha!.id, config: { equals: cfg } },
        data: { nome: 'não devia' },
      }),
    );
    expect(igual.count).toBe(1);
    expect(diferente.count).toBe(0);
  });
});
