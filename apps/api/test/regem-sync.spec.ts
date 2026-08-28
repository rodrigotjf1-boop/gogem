import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RegemImportService } from '../src/integracoes/regem/regem-import.service';
import { RegemSyncPoller } from '../src/integracoes/regem/regem-sync.poller';
import { RegemInboundService } from '../src/integracoes/regem/regem-inbound.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { CardapioService } from '../src/cardapio/cardapio.service';
import type { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import type { ConfigService } from '@nestjs/config';
import type { CatalogoPublicacaoService } from '../src/catalogo/catalogo-publicacao.service';

function makeImport() {
  const prisma = {
    produto: { findMany: vi.fn(), update: vi.fn().mockResolvedValue({}) },
    // Fonte da verdade: sem config = padrão (Regem espelha preço e disponib.).
    integracao: {
      findFirst: vi.fn().mockResolvedValue(null),
      update: vi.fn().mockResolvedValue({}),
    },
    catalogoConflito: {
      findMany: vi.fn().mockResolvedValue([]),
      findFirst: vi.fn(),
      create: vi.fn().mockResolvedValue({}),
      update: vi.fn().mockResolvedValue({}),
      delete: vi.fn().mockResolvedValue({}),
    },
  };
  const client = { fetchCatalogo: vi.fn() };
  const cardapios = { resolverAlvo: vi.fn().mockResolvedValue('card-1') };
  const service = new RegemImportService(
    prisma as unknown as PrismaService,
    client as unknown as RegemCatalogClient,
    cardapios as unknown as CardapioService,
  );
  return { service, prisma, client };
}

describe('RegemImportService.sincronizarLinkados', () => {
  beforeEach(() => vi.clearAllMocks());

  it('atualiza SÓ os campos mudados dos produtos linkados; não toca inalterados', async () => {
    const { service, prisma, client } = makeImport();
    client.fetchCatalogo.mockResolvedValue({
      geradoEm: '2026-07-31',
      categorias: [],
      produtos: [
        {
          codigo: '101',
          nome: 'X-Burger PRO',
          descricao: 'novo texto',
          precoVenda: 34.9, // era 2990 no GoGeM
          ativo: true,
          disponivelCardapio: true,
        },
        {
          codigo: '201',
          nome: 'Refri',
          precoVenda: 8.0, // igual → sem update
          ativo: true,
          disponivelCardapio: true,
        },
      ],
    });
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'p1',
        nome: 'X-Burger',
        descricao: 'antigo',
        precoCentavos: 2990,
        disponivel: true,
        externalRefs: [{ sistema: 'regem', codigo_pdv: '101' }],
      },
      {
        id: 'p2',
        nome: 'Refri',
        descricao: null,
        precoCentavos: 800,
        disponivel: true,
        externalRefs: [{ sistema: 'regem', codigo_pdv: '201' }],
      },
      {
        id: 'p3', // sem código regem → ignorado
        nome: 'Item local',
        descricao: null,
        precoCentavos: 500,
        disponivel: true,
        externalRefs: [],
      },
    ]);

    const r = await service.sincronizarLinkados();

    expect(r).toEqual({ verificados: 2, alterados: 1 });
    expect(prisma.produto.update).toHaveBeenCalledTimes(1);
    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'p1' },
      data: {
        precoCentavos: 3490,
        nome: 'X-Burger PRO',
        descricao: 'novo texto',
      },
    });
  });

  it('pausa no Regem (canal totem) reflete disponivel=false no GoGeM', async () => {
    const { service, prisma, client } = makeImport();
    client.fetchCatalogo.mockResolvedValue({
      geradoEm: '2026-07-31',
      categorias: [],
      produtos: [
        {
          codigo: '101',
          nome: 'X-Burger',
          precoVenda: 29.9,
          ativo: true,
          disponivelCardapio: true,
          canaisPausados: ['totem'],
        },
      ],
    });
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'p1',
        nome: 'X-Burger',
        descricao: null,
        precoCentavos: 2990,
        disponivel: true,
        externalRefs: [{ sistema: 'regem', codigo_pdv: '101' }],
      },
    ]);

    const r = await service.sincronizarLinkados();
    expect(r.alterados).toBe(1);
    expect(prisma.produto.update.mock.calls[0][0].data).toEqual({
      disponivel: false,
    });
  });

  it('fonte da verdade: preço/disponibilidade DESLIGADOS não são sobrescritos', async () => {
    const { service, prisma, client } = makeImport();
    prisma.integracao.findFirst.mockResolvedValue({
      config: { precoSegueRegem: 'false', dispSegueRegem: 'false' },
    });
    client.fetchCatalogo.mockResolvedValue({
      geradoEm: '2026-07-31',
      categorias: [],
      produtos: [
        {
          codigo: '101',
          nome: 'X-Burger', // igual → não muda nome
          precoVenda: 34.9, // difere, mas preço está DESLIGADO
          ativo: false,
          disponivelCardapio: false, // difere, mas disponib. DESLIGADA
          canaisPausados: ['totem'],
        },
      ],
    });
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'p1',
        nome: 'X-Burger',
        descricao: null,
        precoCentavos: 2990,
        disponivel: true,
        externalRefs: [{ sistema: 'regem', codigo_pdv: '101' }],
      },
    ]);

    const r = await service.sincronizarLinkados();
    // Preço e disponibilidade gerenciados no GoGeM → nada a atualizar.
    expect(r.alterados).toBe(0);
    expect(prisma.produto.update).not.toHaveBeenCalled();
  });
});

describe('RegemImportService.novidades / ignorarNovidade', () => {
  it('lista novos (sem par + não-ignorados) e órfãos (sumiram do Regem)', async () => {
    const { service, prisma, client } = makeImport();
    prisma.integracao.findFirst.mockResolvedValue({
      config: { ignorados: ['303'] },
    });
    client.fetchCatalogo.mockResolvedValue({
      geradoEm: '2026-07-31',
      categorias: [],
      produtos: [
        { codigo: '101', nome: 'X-Burger', precoVenda: 29.9 }, // linkado
        { codigo: '202', nome: 'Novo Combo', precoVenda: 39.9 }, // novo
        { codigo: '303', nome: 'Ignorado', precoVenda: 9.9 }, // ignorado
      ],
    });
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'p1',
        nome: 'X-Burger',
        externalRefs: [{ sistema: 'regem', codigo_pdv: '101' }],
      },
      {
        id: 'p9',
        nome: 'Sumiu do Regem',
        externalRefs: [{ sistema: 'regem', codigo_pdv: '999' }],
      },
    ]);

    const out = await service.novidades();
    expect(out.novos).toEqual([
      { codigo: '202', nome: 'Novo Combo', precoCentavos: 3990 },
    ]);
    expect(out.orfaos).toEqual([
      { id: 'p9', nome: 'Sumiu do Regem', codigo: '999' },
    ]);
  });

  it('ignorarNovidade acrescenta o código sem duplicar', async () => {
    const { service, prisma } = makeImport();
    prisma.integracao.findFirst.mockResolvedValue({
      id: 'int-1',
      config: { ignorados: ['303'] },
    });

    const r = await service.ignorarNovidade('202');
    expect(r.ignorados).toEqual(['303', '202']);
    expect(prisma.integracao.update).toHaveBeenCalledWith({
      where: { id: 'int-1' },
      data: { config: { ignorados: ['303', '202'] } },
    });
  });
});

describe('RegemImportService — conflitos (F3)', () => {
  it('loja é a fonte do preço e o Regem diverge → abre conflito', async () => {
    const { service, prisma, client } = makeImport();
    prisma.integracao.findFirst.mockResolvedValue({
      config: { precoSegueRegem: 'false' }, // preço gerido no GoGeM
    });
    client.fetchCatalogo.mockResolvedValue({
      geradoEm: '2026-07-31',
      categorias: [],
      produtos: [
        {
          codigo: '101',
          nome: 'X-Burger',
          precoVenda: 34.9, // diverge do GoGeM (29,90)
          ativo: true,
          disponivelCardapio: true,
        },
      ],
    });
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'p1',
        nome: 'X-Burger',
        descricao: null,
        precoCentavos: 2990,
        disponivel: true,
        externalRefs: [{ sistema: 'regem', codigo_pdv: '101' }],
      },
    ]);

    await service.sincronizarLinkados();
    // Preço não sobrescrito; conflito aberto com os dois valores.
    expect(prisma.produto.update).not.toHaveBeenCalled();
    expect(prisma.catalogoConflito.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        produtoId: 'p1',
        campo: 'preco',
        valorRegem: '3490',
        valorGogem: '2990',
      }),
    });
  });

  it('resolver "regem" aplica o valor do Regem no produto e fecha', async () => {
    const { service, prisma } = makeImport();
    prisma.catalogoConflito.findFirst.mockResolvedValue({
      id: 'cf1',
      produtoId: 'p1',
      campo: 'preco',
      valorRegem: '3490',
    });

    await service.resolverConflito('cf1', 'regem');
    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'p1' },
      data: { precoCentavos: 3490 },
    });
    expect(prisma.catalogoConflito.delete).toHaveBeenCalledWith({
      where: { id: 'cf1' },
    });
  });

  it('resolver "gogem" silencia (status ignorado), sem tocar no produto', async () => {
    const { service, prisma } = makeImport();
    prisma.catalogoConflito.findFirst.mockResolvedValue({
      id: 'cf1',
      produtoId: 'p1',
      campo: 'preco',
      valorRegem: '3490',
    });

    await service.resolverConflito('cf1', 'gogem');
    expect(prisma.produto.update).not.toHaveBeenCalled();
    expect(prisma.catalogoConflito.update).toHaveBeenCalledWith({
      where: { id: 'cf1' },
      data: { status: 'ignorado' },
    });
  });
});

function makePoller() {
  const prisma = {
    integracao: { findMany: vi.fn() },
    catalogoConflito: { count: vi.fn().mockResolvedValue(0) },
    telemetriaEvento: { create: vi.fn().mockResolvedValue({}) },
  };
  const config = { get: vi.fn() };
  const imports = { sincronizarLinkados: vi.fn() };
  const publicacao = { publicar: vi.fn().mockResolvedValue({}) };
  const poller = new RegemSyncPoller(
    prisma as unknown as PrismaService,
    config as unknown as ConfigService,
    imports as unknown as RegemImportService,
    publicacao as unknown as CatalogoPublicacaoService,
  );
  return { poller, prisma, imports, publicacao };
}

describe('RegemSyncPoller.tick', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sincroniza cada tenant com Regem ativo e republica só quando mudou', async () => {
    const { poller, prisma, imports, publicacao } = makePoller();
    prisma.integracao.findMany.mockResolvedValue([
      { tenantId: 't1' },
      { tenantId: 't2' },
    ]);
    imports.sincronizarLinkados
      .mockResolvedValueOnce({ verificados: 3, alterados: 2 }) // t1 mudou
      .mockResolvedValueOnce({ verificados: 3, alterados: 0 }); // t2 igual

    await poller.tick();

    // Buscou só integrações regem ativas.
    expect(prisma.integracao.findMany.mock.calls[0][0].where).toEqual({
      tipo: 'regem',
      ativo: true,
    });
    expect(imports.sincronizarLinkados).toHaveBeenCalledTimes(2);
    // Republica só o tenant que teve alteração.
    expect(publicacao.publicar).toHaveBeenCalledTimes(1);
    expect(publicacao.publicar).toHaveBeenCalledWith(null);
  });

  it('falha de um tenant não interrompe os demais', async () => {
    const { poller, prisma, imports, publicacao } = makePoller();
    prisma.integracao.findMany.mockResolvedValue([
      { tenantId: 't1' },
      { tenantId: 't2' },
    ]);
    imports.sincronizarLinkados
      .mockRejectedValueOnce(new Error('Regem 500'))
      .mockResolvedValueOnce({ verificados: 1, alterados: 1 });

    await poller.tick();

    expect(imports.sincronizarLinkados).toHaveBeenCalledTimes(2);
    expect(publicacao.publicar).toHaveBeenCalledTimes(1); // só o t2 que deu certo
  });

  it('F4 — registra telemetria do espelho quando há sync ou conflitos', async () => {
    const { poller, prisma, imports } = makePoller();
    prisma.integracao.findMany.mockResolvedValue([{ tenantId: 't1' }]);
    imports.sincronizarLinkados.mockResolvedValue({
      verificados: 5,
      alterados: 0,
    });
    prisma.catalogoConflito.count.mockResolvedValue(2); // sem sync, mas há conflitos

    await poller.tick();

    expect(prisma.telemetriaEvento.create).toHaveBeenCalledTimes(1);
    const data = prisma.telemetriaEvento.create.mock.calls[0][0].data;
    expect(data.dispositivoId).toBe('espelho-regem');
    expect(data.nivel).toBe('aviso'); // há conflitos → aviso
    expect(data.mensagem).toContain('2 conflito(s)');
  });

  it('F4 — sem sync e sem conflitos NÃO registra telemetria (não spamma)', async () => {
    const { poller, prisma, imports } = makePoller();
    prisma.integracao.findMany.mockResolvedValue([{ tenantId: 't1' }]);
    imports.sincronizarLinkados.mockResolvedValue({
      verificados: 5,
      alterados: 0,
    });
    prisma.catalogoConflito.count.mockResolvedValue(0);

    await poller.tick();
    expect(prisma.telemetriaEvento.create).not.toHaveBeenCalled();
  });
});

function makeInbound() {
  const prisma = { integracao: { findFirst: vi.fn() } };
  const imports = { sincronizarLinkados: vi.fn() };
  const publicacao = { publicar: vi.fn().mockResolvedValue({}) };
  const cancelamento = { cancelarPorChave: vi.fn() };
  const service = new RegemInboundService(
    prisma as unknown as PrismaService,
    imports as unknown as RegemImportService,
    publicacao as unknown as CatalogoPublicacaoService,
    cancelamento as unknown as import('../src/pagamentos/cancelamento.service').CancelamentoService,
  );
  return { service, prisma, imports, publicacao, cancelamento };
}

describe('RegemInboundService.publicar (botão "Publicar no GoGeM")', () => {
  beforeEach(() => vi.clearAllMocks());

  it('token válido → acha o tenant, sincroniza e republica se mudou', async () => {
    const { service, prisma, imports, publicacao } = makeInbound();
    prisma.integracao.findFirst.mockResolvedValue({ tenantId: 't1' });
    imports.sincronizarLinkados.mockResolvedValue({
      verificados: 3,
      alterados: 2,
    });

    const r = await service.publicar('tok-abc');

    expect(r).toEqual({ alterados: 2 });
    // Casou pelo token dentro do config (cross-tenant, só regem ativo).
    const where = prisma.integracao.findFirst.mock.calls[0][0].where;
    expect(where.tipo).toBe('regem');
    expect(where.ativo).toBe(true);
    expect(where.config).toEqual({ path: ['token'], equals: 'tok-abc' });
    expect(publicacao.publicar).toHaveBeenCalledWith(null);
  });

  it('token válido mas nada mudou → NÃO republica', async () => {
    const { service, prisma, imports, publicacao } = makeInbound();
    prisma.integracao.findFirst.mockResolvedValue({ tenantId: 't1' });
    imports.sincronizarLinkados.mockResolvedValue({
      verificados: 3,
      alterados: 0,
    });
    const r = await service.publicar('tok-abc');
    expect(r).toEqual({ alterados: 0 });
    expect(publicacao.publicar).not.toHaveBeenCalled();
  });

  it('token inexistente → 401', async () => {
    const { service, prisma } = makeInbound();
    prisma.integracao.findFirst.mockResolvedValue(null);
    await expect(service.publicar('nope')).rejects.toThrow();
  });

  it('token vazio → 401 (sem consultar)', async () => {
    const { service, prisma } = makeInbound();
    await expect(service.publicar('')).rejects.toThrow();
    expect(prisma.integracao.findFirst).not.toHaveBeenCalled();
  });
});
