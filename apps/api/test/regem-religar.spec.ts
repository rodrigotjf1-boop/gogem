import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RegemImportService } from '../src/integracoes/regem/regem-import.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { CardapioService } from '../src/cardapio/cardapio.service';
import type { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';

/**
 * ERR-035 — o Regem trocou o código PDV de 61 produtos (migration 331, 20/10/2026). O vínculo do GoGeM era só o
 * código: 57 produtos ficaram sem par e 4 passaram a espelhar OUTRO produto (o código antigo deles virou o novo de
 * outro — ex.: um combo era o 10 e ficou 85; um refrigerante ficou com o 10). Aqui: o vínculo com `regem_id`
 * segue o produto pelo id e o código acompanha.
 */

function makeService() {
  const prisma = {
    produto: {
      findMany: vi.fn().mockResolvedValue([]),
      update: vi.fn().mockResolvedValue({}),
      create: vi.fn().mockImplementation(async ({ data }: any) => ({
        id: 'gp-novo',
        ...data,
      })),
    },
    categoria: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockImplementation(async ({ data }: any) => ({
        id: `gc-${data.nome}`,
        ...data,
      })),
      update: vi.fn().mockResolvedValue({}),
    },
    complementoGrupo: { findMany: vi.fn(), create: vi.fn(), update: vi.fn() },
    produtoComplemento: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn(),
    },
    complementoOpcao: { findMany: vi.fn(), create: vi.fn(), update: vi.fn() },
    integracao: {
      findFirst: vi.fn().mockResolvedValue(null),
      update: vi.fn().mockResolvedValue({}),
    },
    catalogoConflito: {
      findMany: vi.fn().mockResolvedValue([]),
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

/** Produto do catálogo do Regem. */
const rp = (
  id: string | undefined,
  codigo: string,
  nome: string,
  preco = '10.00',
) => ({
  ...(id ? { id } : {}),
  codigo,
  nome,
  descricao: null,
  precoVenda: preco,
  categoriaId: null,
  disponivelCardapio: true,
  disponivelBalcao: true,
  ativo: true,
  grupos: [],
});

/** Produto do GoGeM com o vínculo regem (com ou sem id). */
const gp = (
  id: string,
  nome: string,
  codigo: string,
  regemId?: string,
  precoCentavos = 1000,
) => ({
  id,
  nome,
  descricao: null,
  precoCentavos,
  disponivel: true,
  externalRefs: [
    {
      sistema: 'regem',
      codigo_pdv: codigo,
      ...(regemId ? { regem_id: regemId } : {}),
    },
  ],
});

const catalogo = (produtos: unknown[]) => ({
  geradoEm: 'x',
  categorias: [],
  produtos,
});

describe('sincronizarLinkados — o vínculo segue o produto pelo id (ERR-035)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('o ciclo do incidente: o código antigo de um é o novo de outro — cada um segue o SEU produto', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([
        rp('id-refri', '10', 'Refrigerante lata', '6.00'),
        rp('id-combo', '85', 'Combo da casa', '39.90'),
      ]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-combo', 'Combo da casa', '10', 'id-combo', 3990),
      gp('g-refri', 'Refrigerante lata', 'cw4620905', 'id-refri', 600),
    ]);

    const r = await service.sincronizarLinkados();

    // Nome e preço intactos: ninguém recebe os dados do outro. Só o código acompanha.
    expect(prisma.produto.update).toHaveBeenCalledTimes(2);
    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'g-combo' },
      data: {
        externalRefs: [
          { sistema: 'regem', codigo_pdv: '85', regem_id: 'id-combo' },
        ],
      },
    });
    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'g-refri' },
      data: {
        externalRefs: [
          { sistema: 'regem', codigo_pdv: '10', regem_id: 'id-refri' },
        ],
      },
    });
    // Código mudou = alterado (o cardápio publicado leva o código com que o totem vende).
    expect(r).toEqual({ verificados: 2, alterados: 2 });
  });

  it('vínculo antigo (sem id) casa pelo código e ganha o id — sem contar como alterado', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-x', '101', 'X-Burger')]),
    );
    prisma.produto.findMany.mockResolvedValue([gp('g-x', 'X-Burger', '101')]);

    const r = await service.sincronizarLinkados();

    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'g-x' },
      data: {
        externalRefs: [
          { sistema: 'regem', codigo_pdv: '101', regem_id: 'id-x' },
        ],
      },
    });
    expect(r).toEqual({ verificados: 1, alterados: 0 });
  });

  it('preserva os refs de outros sistemas ao acompanhar o código', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-x', '200', 'X-Burger')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      {
        ...gp('g-x', 'X-Burger', '101', 'id-x'),
        externalRefs: [
          { sistema: 'ifood', codigo_pdv: 'IF-9' },
          { sistema: 'regem', codigo_pdv: '101', regem_id: 'id-x' },
        ],
      },
    ]);

    await service.sincronizarLinkados();

    expect(prisma.produto.update.mock.calls[0][0].data.externalRefs).toEqual([
      { sistema: 'ifood', codigo_pdv: 'IF-9' },
      { sistema: 'regem', codigo_pdv: '200', regem_id: 'id-x' },
    ]);
  });

  it('id que sumiu do catálogo: não sincroniza nem rouba o código de outro produto', async () => {
    const { service, prisma, client } = makeService();
    // O produto do id-velho saiu do Regem; o código 10 agora é de OUTRO produto.
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-outro', '10', 'Molho da casa', '2.00')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-1', 'Lanche 01', '10', 'id-velho'),
    ]);

    const r = await service.sincronizarLinkados();

    expect(prisma.produto.update).not.toHaveBeenCalled();
    expect(r).toEqual({ verificados: 0, alterados: 0 });
  });

  it('catálogo SEM ids (Regem antigo): o vínculo com id cai para o código', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp(undefined, '101', 'X-Burger PRO')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-x', 'X-Burger', '101', 'id-x'),
    ]);

    const r = await service.sincronizarLinkados();

    // Só o nome (o vínculo fica como está: sem id do outro lado, nada a trocar).
    expect(prisma.produto.update).toHaveBeenCalledWith({
      where: { id: 'g-x' },
      data: { nome: 'X-Burger PRO' },
    });
    expect(r).toEqual({ verificados: 1, alterados: 1 });
  });
});

describe('novidades — com o id, troca de código não vira órfão nem "novo"', () => {
  beforeEach(() => vi.clearAllMocks());

  it('produto com o código trocado no Regem não aparece em lugar nenhum', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-combo', '85', 'Combo da casa')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-combo', 'Combo da casa', '10', 'id-combo'),
    ]);

    await expect(service.novidades()).resolves.toEqual({
      novos: [],
      orfaos: [],
    });
  });

  it('id que sumiu: o produto vira órfão e o do Regem com o mesmo código aparece como novo', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-outro', '10', 'Molho da casa', '2.00')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-1', 'Lanche 01', '10', 'id-velho'),
    ]);

    const r = await service.novidades();

    expect(r.orfaos).toEqual([{ id: 'g-1', nome: 'Lanche 01', codigo: '10' }]);
    expect(r.novos).toEqual([
      { codigo: '10', nome: 'Molho da casa', precoCentavos: 200 },
    ]);
  });
});

describe('importar — casa pelo id e não duplica (ERR-035)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('código trocado no Regem: atualiza o MESMO produto, sem criar outro', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-combo', '85', 'Combo da casa')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-combo', 'Combo da casa', '10', 'id-combo'),
    ]);

    const resumo = await service.importar();

    expect(prisma.produto.create).not.toHaveBeenCalled();
    expect(prisma.produto.update.mock.calls[0][0].where).toEqual({
      id: 'g-combo',
    });
    expect(prisma.produto.update.mock.calls[0][0].data.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: '85', regem_id: 'id-combo' },
    ]);
    expect(resumo.produtos).toEqual({
      criados: 0,
      atualizados: 1,
      ignoradosSemCodigo: 0,
    });
  });

  it('o código antigo de um produto ainda no Regem NÃO serve para outro: o outro nasce produto novo', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([
        rp('id-combo', '85', 'Combo da casa'),
        rp('id-refri', '10', 'Refrigerante lata', '6.00'),
      ]),
    );
    // Só o combo está no GoGeM, ainda com o código antigo (10).
    prisma.produto.findMany.mockResolvedValue([
      gp('g-combo', 'Combo da casa', '10', 'id-combo'),
    ]);

    await service.importar();

    // O combo segue o id; o refrigerante (que ficou com o 10) não toma o par do combo.
    expect(prisma.produto.update).toHaveBeenCalledTimes(1);
    expect(prisma.produto.update.mock.calls[0][0].where).toEqual({
      id: 'g-combo',
    });
    expect(prisma.produto.create).toHaveBeenCalledTimes(1);
    expect(prisma.produto.create.mock.calls[0][0].data.nome).toBe(
      'Refrigerante lata',
    );
    expect(prisma.produto.create.mock.calls[0][0].data.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: '10', regem_id: 'id-refri' },
    ]);
  });

  it('id que sumiu do Regem (produto recriado com o mesmo código): religa pelo código', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([rp('id-novo', '101', 'X-Burger')]),
    );
    prisma.produto.findMany.mockResolvedValue([
      gp('g-x', 'X-Burger', '101', 'id-velho'),
    ]);

    await service.importar();

    expect(prisma.produto.create).not.toHaveBeenCalled();
    expect(prisma.produto.update.mock.calls[0][0].data.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: '101', regem_id: 'id-novo' },
    ]);
  });
});
