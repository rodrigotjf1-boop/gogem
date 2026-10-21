import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PrismaService } from '../src/prisma/prisma.service';
import { TenantContext } from '../src/tenant/tenant-context';

/**
 * ERR-035 — a migration `20261021000000_religar_codigos_pdv_regem` contra um Postgres DE VERDADE (opt-in): o
 * ciclo (o código antigo de um é o novo de outro), refs de outros sistemas, ref que já tem id, dado fora do
 * formato, duplicado de um importar posterior, loja do Regem de testes e loja sem integração. Rodar num banco
 * DESCARTÁVEL já migrado (`prisma migrate deploy`):
 *   RELIGAR_PG_URL=postgresql://…/banco_descartavel npx vitest run test/religar-codigos-pdv.pg.spec.ts
 * Apaga os tenants "religar-…" desse banco.
 */
const URL = process.env.RELIGAR_PG_URL;
const SQL = readFileSync(
  join(
    __dirname,
    '..',
    'prisma',
    'migrations',
    '20261021000000_religar_codigos_pdv_regem',
    'migration.sql',
  ),
  'utf8',
);

describe.skipIf(!URL)('migration religar códigos PDV — Postgres real', () => {
  let prisma: PrismaService;
  // Callback async: com o síncrono a consulta roda fora do contexto (ERR-031).
  const sistema = <T>(fn: () => Promise<T>) =>
    TenantContext.runAsSystem(async () => {
      const r = await fn();
      return r;
    });
  const ids: Record<string, string> = {};

  const refs = async (id: string) =>
    sistema(async () => {
      const p = await prisma.produto.findFirst({ where: { id } });
      return p?.externalRefs;
    });

  beforeAll(async () => {
    process.env.DATABASE_URL = URL;
    prisma = new PrismaService();
    await prisma.$connect();
    await sistema(async () => {
      const velhos = await prisma.tenant.findMany({
        where: { nome: { startsWith: 'religar-' } },
        select: { id: true },
      });
      const tids = velhos.map((t) => t.id);
      await prisma.produto.deleteMany({ where: { tenantId: { in: tids } } });
      await prisma.cardapio.deleteMany({ where: { tenantId: { in: tids } } });
      await prisma.integracao.deleteMany({ where: { tenantId: { in: tids } } });
      await prisma.tenant.deleteMany({ where: { id: { in: tids } } });

      const tA = (
        await prisma.tenant.create({ data: { nome: 'religar-prod' } })
      ).id;
      const tB = (await prisma.tenant.create({ data: { nome: 'religar-stg' } }))
        .id;
      const tC = (await prisma.tenant.create({ data: { nome: 'religar-sem' } }))
        .id;
      await prisma.integracao.createMany({
        data: [
          {
            tenantId: tA,
            tipo: 'regem',
            ativo: true,
            config: {
              apiBase: 'https://api.dmsregem.com/api/v1',
              token: 'v1.x',
            },
          },
          {
            tenantId: tB,
            tipo: 'regem',
            ativo: true,
            config: { apiBase: 'https://api-stg.dmsregem.com/api/v1' },
          },
        ],
      });
      const cA1 = (
        await prisma.cardapio.create({
          data: { tenantId: tA, nome: 'Ativo', ativo: true },
        })
      ).id;
      const cA2 = (
        await prisma.cardapio.create({
          data: { tenantId: tA, nome: 'Em preparo' },
        })
      ).id;
      const cB = (
        await prisma.cardapio.create({ data: { tenantId: tB, nome: 'B' } })
      ).id;
      const cC = (
        await prisma.cardapio.create({ data: { tenantId: tC, nome: 'C' } })
      ).id;

      const produto = async (
        chave: string,
        tenantId: string,
        cardapioId: string,
        externalRefs: unknown,
      ) => {
        const p = await prisma.produto.create({
          data: {
            tenantId,
            cardapioId,
            nome: chave,
            precoCentavos: 100,
            externalRefs: externalRefs as never,
          },
        });
        ids[chave] = p.id;
      };
      // Loja de produção — o ciclo 10 → 85 e cw4620905 → 10; o 30 → 46 e cw4620892 → 30.
      await produto('combo', tA, cA1, [{ sistema: 'regem', codigo_pdv: '10' }]);
      await produto('refri', tA, cA1, [
        { sistema: 'regem', codigo_pdv: 'cw4620905' },
      ]);
      await produto('numero01', tA, cA1, [
        { sistema: 'ifood', codigo_pdv: '30' },
        { sistema: 'regem', codigo_pdv: '30', loja: 'centro' },
      ]);
      await produto('molho', tA, cA1, [
        { sistema: 'regem', codigo_pdv: ' cw4620892 ' },
      ]);
      await produto('fora', tA, cA1, [{ sistema: 'regem', codigo_pdv: '999' }]);
      await produto('local', tA, cA1, []);
      await produto('jaTemId', tA, cA1, [
        { sistema: 'regem', codigo_pdv: 'cw4620894', regem_id: 'id-de-antes' },
      ]);
      await produto('objeto', tA, cA1, { sistema: 'regem', codigo_pdv: '10' });
      await produto('misturado', tA, cA1, [
        'texto',
        { sistema: 'regem', codigo_pdv: 'cw4620906' },
      ]);
      // O código novo dele (8) é o ANTIGO de outro (um combo: 8 → 76), que não está no GoGeM: rodar a
      // migration de novo sem a trava "só ref sem id" andaria o ciclo (8 → 76).
      await produto('semPar', tA, cA1, [
        { sistema: 'regem', codigo_pdv: 'cw4620875' },
      ]);
      // Outro cardápio: um importar DEPOIS da troca já criou o produto com o código novo (2).
      await produto('antigoComGemeo', tA, cA2, [
        { sistema: 'regem', codigo_pdv: 'cw4620899' },
      ]);
      await produto('gemeoNovo', tA, cA2, [
        { sistema: 'regem', codigo_pdv: '2' },
      ]);
      // Lojas fora: Regem de testes e sem integração.
      await produto('stg', tB, cB, [{ sistema: 'regem', codigo_pdv: '10' }]);
      await produto('semIntegracao', tC, cC, [
        { sistema: 'regem', codigo_pdv: '10' },
      ]);
    });
    await prisma.$executeRawUnsafe(SQL);
  });

  afterAll(async () => {
    await prisma?.$disconnect();
  });

  it('o ciclo: cada produto vai para o código novo do SEU produto no Regem, com o id', async () => {
    expect(await refs(ids.combo)).toEqual([
      {
        sistema: 'regem',
        codigo_pdv: '85',
        regem_id: '3e9695c8-6607-4625-9211-ebb32fa9c8ff',
      },
    ]);
    expect(await refs(ids.refri)).toEqual([
      {
        sistema: 'regem',
        codigo_pdv: '10',
        regem_id: 'cc0ae91f-9b8a-4ab4-9ea6-1decefdfb30f',
      },
    ]);
    expect(await refs(ids.molho)).toEqual([
      {
        sistema: 'regem',
        codigo_pdv: '30',
        regem_id: '3004e652-ccda-49a1-8f6a-9b566440e2eb',
      },
    ]);
  });

  it('ref de outro sistema e a `loja` do ref regem ficam como estavam', async () => {
    expect(await refs(ids.numero01)).toEqual([
      { sistema: 'ifood', codigo_pdv: '30' },
      {
        sistema: 'regem',
        codigo_pdv: '46',
        loja: 'centro',
        regem_id: '29b90f93-0696-4ed8-a8b4-32e4e79ca116',
      },
    ]);
  });

  it('não mexe: código fora da lista, sem ref, ref com id, Json que não é lista', async () => {
    expect(await refs(ids.fora)).toEqual([
      { sistema: 'regem', codigo_pdv: '999' },
    ]);
    expect(await refs(ids.local)).toEqual([]);
    expect(await refs(ids.jaTemId)).toEqual([
      { sistema: 'regem', codigo_pdv: 'cw4620894', regem_id: 'id-de-antes' },
    ]);
    expect(await refs(ids.objeto)).toEqual({
      sistema: 'regem',
      codigo_pdv: '10',
    });
  });

  it('elemento que não é objeto fica; o ref regem ao lado é religado', async () => {
    expect(await refs(ids.misturado)).toEqual([
      'texto',
      {
        sistema: 'regem',
        codigo_pdv: '11',
        regem_id: '158c7445-b847-4aa3-a8c1-996880a3f7da',
      },
    ]);
  });

  it('com o "gêmeo" de um importar posterior no mesmo cardápio, o antigo fica de fora (revisão do dono)', async () => {
    expect(await refs(ids.antigoComGemeo)).toEqual([
      { sistema: 'regem', codigo_pdv: 'cw4620899' },
    ]);
    expect(await refs(ids.gemeoNovo)).toEqual([
      { sistema: 'regem', codigo_pdv: '2' },
    ]);
  });

  it('só a loja ligada ao Regem de produção: a do Regem de testes e a sem integração não mudam', async () => {
    expect(await refs(ids.stg)).toEqual([
      { sistema: 'regem', codigo_pdv: '10' },
    ]);
    expect(await refs(ids.semIntegracao)).toEqual([
      { sistema: 'regem', codigo_pdv: '10' },
    ]);
  });

  it('rodar de novo não muda nada (o ciclo não anda duas vezes)', async () => {
    expect(await refs(ids.semPar)).toEqual([
      {
        sistema: 'regem',
        codigo_pdv: '8',
        regem_id: 'a271fd40-9146-4bad-8c8a-93fb4e6648d1',
      },
    ]);
    const antes = await Promise.all(Object.values(ids).map((id) => refs(id)));
    const n = await prisma.$executeRawUnsafe(SQL);
    expect(n).toBe(0);
    const depois = await Promise.all(Object.values(ids).map((id) => refs(id)));
    expect(depois).toEqual(antes);
  });
});
