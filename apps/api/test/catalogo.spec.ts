import { NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CatalogoPublicacaoService } from '../src/catalogo/catalogo-publicacao.service';
import type { CardapioService } from '../src/cardapio/cardapio.service';
import type { AparenciaService } from '../src/aparencia/aparencia.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    categoria: { findMany: vi.fn() },
    produto: { findMany: vi.fn() },
    produtoUpsell: { findMany: vi.fn().mockResolvedValue([]) },
    menuVersion: {
      aggregate: vi.fn(),
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
    },
  };
  // Cardápio ativo resolvido para 'card-1' (Fase 3B).
  const cardapios = { ativoId: vi.fn().mockResolvedValue('card-1') };
  // Aparência do tenant (Fase 6) — vai junto no /catalogo/publicado.
  const aparencia = {
    obter: vi.fn().mockResolvedValue({ id: 'ap-1', corPrimaria: '#FFC24B' }),
  };
  const service = new CatalogoPublicacaoService(
    prisma as unknown as PrismaService,
    cardapios as unknown as CardapioService,
    aparencia as unknown as AparenciaService,
  );
  return { service, prisma, cardapios, aparencia };
}

/** Rascunho de exemplo: 2 categorias, 1 produto com 1 grupo de 2 opções. */
function seedDraft(prisma: ReturnType<typeof makeService>['prisma']) {
  prisma.categoria.findMany.mockResolvedValue([
    { id: 'c-1', nome: 'Lanches', ordem: 0 },
    { id: 'c-2', nome: 'Bebidas', ordem: 1 },
  ]);
  prisma.produto.findMany.mockResolvedValue([
    {
      id: 'p-1',
      nome: 'X-Salada',
      descricao: 'Clássico',
      precoCentavos: 2590,
      disponivel: true,
      imagemUrl: null,
      selo: 'Mais vendido',
      categoriaId: 'c-1',
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'PROD-1' }],
      // Etapas via vínculo (reutilizáveis): { ordem, grupo{ opcoes } }.
      complementos: [
        {
          ordem: 0,
          grupo: {
            id: 'g-1',
            nome: 'Ponto da carne',
            min: 1,
            max: 1,
            obrigatorio: true,
            opcoes: [
              {
                id: 'o-1',
                nome: 'Ao ponto',
                precoCentavosDelta: 0,
                disponivel: true,
                imagemUrl: null,
                ordem: 0,
                externalRefs: [],
              },
              {
                id: 'o-2',
                nome: 'Bem passada',
                precoCentavosDelta: 0,
                disponivel: false,
                imagemUrl: null,
                ordem: 1,
                externalRefs: [],
              },
            ],
          },
        },
      ],
    },
  ]);
}

describe('CatalogoPublicacaoService — publicar', () => {
  beforeEach(() => vi.clearAllMocks());

  it('monta o snapshot do rascunho, calcula versao = max+1 e cria SEM tenantId manual', async () => {
    const { service, prisma } = makeService();
    seedDraft(prisma);
    prisma.menuVersion.aggregate.mockResolvedValue({ _max: { versao: 4 } });
    const publishedAt = new Date('2026-07-25T12:00:00.000Z');
    prisma.menuVersion.create.mockResolvedValue({ versao: 5, publishedAt });

    const res = await service.publicar('u-1');

    // Versão incrementada e totais corretos.
    expect(res.versao).toBe(5);
    expect(res.publishedAt).toBe(publishedAt);
    expect(res.totais).toEqual({
      categorias: 2,
      produtos: 1,
      grupos: 1,
      opcoes: 2,
    });

    // Argumentos do create: versao, snapshot bem-formado, publishedById, SEM tenantId.
    const data = prisma.menuVersion.create.mock.calls[0][0].data;
    expect(data.versao).toBe(5);
    expect(data.publishedById).toBe('u-1');
    expect('tenantId' in data).toBe(false);
    expect(
      JSON.stringify(prisma.menuVersion.create.mock.calls[0][0]),
    ).not.toContain('tenantId');

    // Shape do snapshot (§3): inclui produto indisponível-por-opção e todos os campos.
    const snap = data.snapshot;
    expect(typeof snap.geradoEm).toBe('string');
    expect(snap.categorias).toEqual([
      { id: 'c-1', nome: 'Lanches', ordem: 0 },
      { id: 'c-2', nome: 'Bebidas', ordem: 1 },
    ]);
    expect(snap.produtos).toHaveLength(1);
    const prod = snap.produtos[0];
    expect(prod.upsell).toEqual([]); // sem upsell configurado
    expect(prod.selo).toBe('Mais vendido'); // selo de destaque (F4)
    expect(prod).toMatchObject({
      id: 'p-1',
      nome: 'X-Salada',
      descricao: 'Clássico',
      precoCentavos: 2590,
      disponivel: true,
      categoriaId: 'c-1',
      externalRefs: [{ sistema: 'regem', codigo_pdv: 'PROD-1' }],
    });
    expect(prod.grupos[0]).toMatchObject({
      id: 'g-1',
      nome: 'Ponto da carne',
      min: 1,
      max: 1,
      obrigatorio: true,
      ordem: 0,
    });
    expect(prod.grupos[0].opcoes).toHaveLength(2);
    // Inclui opção indisponível (disponibilidade é campo, não filtro).
    expect(prod.grupos[0].opcoes[1]).toMatchObject({
      id: 'o-2',
      disponivel: false,
    });
  });

  it('inclui upsell no snapshot, só para sugeridos no cardápio (sem órfãos)', async () => {
    const { service, prisma } = makeService();
    prisma.categoria.findMany.mockResolvedValue([]);
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'p-1',
        nome: 'Burger',
        precoCentavos: 2590,
        disponivel: true,
        imagemUrl: null,
        categoriaId: null,
        descricao: null,
        externalRefs: [],
        complementos: [],
      },
      {
        id: 'p-2',
        nome: 'Refri',
        precoCentavos: 800,
        disponivel: true,
        imagemUrl: null,
        categoriaId: null,
        descricao: null,
        externalRefs: [],
        complementos: [],
      },
    ]);
    // p-1 sugere p-2 (no cardápio) e p-9 (fora do cardápio → filtrado).
    prisma.produtoUpsell.findMany.mockResolvedValue([
      { produtoId: 'p-1', sugeridoId: 'p-2' },
      { produtoId: 'p-1', sugeridoId: 'p-9' },
    ]);
    prisma.menuVersion.aggregate.mockResolvedValue({ _max: { versao: 0 } });
    prisma.menuVersion.create.mockResolvedValue({
      versao: 1,
      publishedAt: new Date(),
    });

    await service.publicar('u-1');
    const snap = prisma.menuVersion.create.mock.calls[0][0].data.snapshot;
    const burger = snap.produtos.find((p: { id: string }) => p.id === 'p-1');
    const refri = snap.produtos.find((p: { id: string }) => p.id === 'p-2');
    expect(burger.upsell).toEqual(['p-2']); // p-9 (órfão) removido
    expect(refri.upsell).toEqual([]);
  });

  it('primeira publicação (nenhuma versão) começa em 1', async () => {
    const { service, prisma } = makeService();
    seedDraft(prisma);
    prisma.menuVersion.aggregate.mockResolvedValue({ _max: { versao: null } });
    prisma.menuVersion.create.mockResolvedValue({
      versao: 1,
      publishedAt: new Date(),
    });

    const res = await service.publicar(null);
    expect(res.versao).toBe(1);
    expect(prisma.menuVersion.create.mock.calls[0][0].data.versao).toBe(1);
    expect(prisma.menuVersion.create.mock.calls[0][0].data.publishedById).toBe(
      null,
    );
  });

  it('em colisão P2002 retenta uma vez com versao+1', async () => {
    const { service, prisma } = makeService();
    seedDraft(prisma);
    prisma.menuVersion.aggregate.mockResolvedValue({ _max: { versao: 2 } });
    const p2002 = new Prisma.PrismaClientKnownRequestError('unique', {
      code: 'P2002',
      clientVersion: '5.20.0',
    });
    prisma.menuVersion.create
      .mockRejectedValueOnce(p2002)
      .mockResolvedValueOnce({ versao: 4, publishedAt: new Date() });

    const res = await service.publicar('u-1');

    expect(res.versao).toBe(4);
    expect(prisma.menuVersion.create).toHaveBeenCalledTimes(2);
    expect(prisma.menuVersion.create.mock.calls[0][0].data.versao).toBe(3);
    expect(prisma.menuVersion.create.mock.calls[1][0].data.versao).toBe(4);
  });
});

describe('CatalogoPublicacaoService — publicado / versoes', () => {
  beforeEach(() => vi.clearAllMocks());

  it('getPublicado retorna a última versão com snapshot e atualizado:true', async () => {
    const { service, prisma } = makeService();
    const publishedAt = new Date('2026-07-25T00:00:00.000Z');
    prisma.menuVersion.findFirst.mockResolvedValue({
      versao: 7,
      publishedAt,
      snapshot: { geradoEm: 'x', categorias: [], produtos: [] },
    });

    const res = await service.getPublicado();
    expect(res).toEqual({
      versao: 7,
      publishedAt,
      snapshot: { geradoEm: 'x', categorias: [], produtos: [] },
      atualizado: true,
      aparencia: { id: 'ap-1', corPrimaria: '#FFC24B' },
    });
    expect(prisma.menuVersion.findFirst).toHaveBeenCalledWith({
      orderBy: { versao: 'desc' },
    });
  });

  it('getPublicado com ?desde >= última → atualizado:false SEM snapshot', async () => {
    const { service, prisma } = makeService();
    prisma.menuVersion.findFirst.mockResolvedValue({
      versao: 7,
      publishedAt: new Date(),
      snapshot: { any: true },
    });

    const res = await service.getPublicado(7);
    expect(res).toEqual({
      versao: 7,
      atualizado: false,
      aparencia: { id: 'ap-1', corPrimaria: '#FFC24B' },
    });
    expect('snapshot' in res).toBe(false);
  });

  it('getPublicado com ?desde < última → devolve o snapshot completo', async () => {
    const { service, prisma } = makeService();
    prisma.menuVersion.findFirst.mockResolvedValue({
      versao: 7,
      publishedAt: new Date(),
      snapshot: { any: true },
    });

    const res = await service.getPublicado(6);
    expect(res).toMatchObject({ versao: 7, atualizado: true });
    expect('snapshot' in res).toBe(true);
  });

  it('getPublicado sem nenhuma versão publicada → 404', async () => {
    const { service, prisma } = makeService();
    prisma.menuVersion.findFirst.mockResolvedValue(null);
    await expect(service.getPublicado()).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('listVersoes retorna metadados sem o corpo do snapshot, do mais novo ao antigo', async () => {
    const { service, prisma } = makeService();
    prisma.menuVersion.findMany.mockResolvedValue([
      { id: 'v-2', versao: 2, publishedAt: new Date(), publishedById: 'u-1' },
      { id: 'v-1', versao: 1, publishedAt: new Date(), publishedById: null },
    ]);

    const res = await service.listVersoes();
    expect(res).toHaveLength(2);
    expect(prisma.menuVersion.findMany).toHaveBeenCalledWith({
      orderBy: { versao: 'desc' },
      select: {
        id: true,
        versao: true,
        publishedAt: true,
        publishedById: true,
      },
    });
    // O select não pede snapshot.
    const select = prisma.menuVersion.findMany.mock.calls[0][0].select;
    expect('snapshot' in select).toBe(false);
  });
});
