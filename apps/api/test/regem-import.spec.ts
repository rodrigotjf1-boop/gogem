import { beforeEach, describe, expect, it, vi } from 'vitest';
import { reaisToCentavos } from '../src/integracoes/regem/reais-to-centavos';
import { RegemImportService } from '../src/integracoes/regem/regem-import.service';
import type { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import type { CardapioService } from '../src/cardapio/cardapio.service';
import type { PrismaService } from '../src/prisma/prisma.service';

/** Monta o serviço com Prisma e client 100% mockados (sem rede, sem DB). */
function makeService() {
  const prisma = {
    categoria: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockImplementation(async ({ data }: any) => ({
        id: `gc-${data.nome}`,
        ...data,
      })),
      update: vi.fn().mockResolvedValue({}),
    },
    produto: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockImplementation(async ({ data }: any) => ({
        id: 'gp-new',
        ...data,
      })),
      update: vi.fn().mockResolvedValue({}),
    },
    complementoGrupo: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: 'gg-1' }),
      update: vi.fn().mockResolvedValue({}),
    },
    complementoOpcao: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: 'go-1' }),
      update: vi.fn().mockResolvedValue({}),
    },
  };
  const client = { fetchCatalogo: vi.fn() };
  const cardapios = { resolverAlvo: vi.fn().mockResolvedValue('card-1') };
  const service = new RegemImportService(
    prisma as unknown as PrismaService,
    client as unknown as RegemCatalogClient,
    cardapios as unknown as CardapioService,
  );
  return { service, prisma, client, cardapios };
}

/** Payload fixo: 2 categorias, 3 produtos (1 sem codigo → skip), 1 com grupo+opção. */
function payload() {
  return {
    geradoEm: '2026-07-25T10:00:00.000Z',
    categorias: [
      { id: 'rc-1', nome: 'Lanches', ordem: 1 },
      { id: 'rc-2', nome: 'Bebidas', ordem: 2 },
    ],
    produtos: [
      {
        id: 'rp-1',
        codigo: 'PROD-1',
        nome: 'X-Burger',
        descricao: 'Delícia',
        precoVenda: '29.90',
        categoriaId: 'rc-1',
        disponivelCardapio: true,
        disponivelBalcao: true,
        ativo: true,
        grupos: [
          {
            id: 'rg-1',
            nome: 'Escolha a bebida',
            tipo: 'unico',
            min: 1,
            max: 1,
            obrigatorio: true,
            ordem: 1,
            opcoes: [
              {
                id: 'ro-1',
                nome: 'Coca-Cola',
                precoDelta: '5.00',
                codigoPdv: 'OPC-1',
                ordem: 1,
              },
            ],
          },
        ],
      },
      {
        id: 'rp-2',
        codigo: null,
        nome: 'Sem código',
        descricao: null,
        precoVenda: '10.00',
        categoriaId: 'rc-2',
        disponivelCardapio: true,
        disponivelBalcao: true,
        ativo: true,
        grupos: [],
      },
      {
        id: 'rp-3',
        codigo: 'PROD-3',
        nome: 'Refrigerante',
        descricao: null,
        precoVenda: '7.50',
        categoriaId: 'rc-2',
        disponivelCardapio: false,
        disponivelBalcao: true,
        ativo: true,
        grupos: [],
      },
    ],
  };
}

/** Junta os args de TODAS as chamadas de escrita para inspeção. */
function todasEscritas(prisma: any): string {
  const calls = [
    ...prisma.categoria.create.mock.calls,
    ...prisma.categoria.update.mock.calls,
    ...prisma.produto.create.mock.calls,
    ...prisma.produto.update.mock.calls,
    ...prisma.complementoGrupo.create.mock.calls,
    ...prisma.complementoGrupo.update.mock.calls,
    ...prisma.complementoOpcao.create.mock.calls,
    ...prisma.complementoOpcao.update.mock.calls,
  ];
  return JSON.stringify(calls);
}

describe('RegemImportService.importar — catálogo novo (tudo criado)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cria categorias/produtos/grupos/opções e devolve o resumo', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(payload());

    const resumo = await service.importar();

    expect(resumo).toEqual({
      geradoEm: '2026-07-25T10:00:00.000Z',
      categorias: { criadas: 2, atualizadas: 0 },
      produtos: { criados: 2, atualizados: 0, ignoradosSemCodigo: 1 },
      grupos: { criados: 1, atualizados: 0 },
      opcoes: { criados: 1, atualizados: 0 },
    });
    // rp-2 (codigo null) foi pulado → só 2 produtos criados.
    expect(prisma.produto.create).toHaveBeenCalledTimes(2);
    expect(prisma.produto.update).not.toHaveBeenCalled();
  });

  it('converte reais→centavos e injeta o de-para regem no produto', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(payload());
    await service.importar();

    const criados = prisma.produto.create.mock.calls.map((c: any) => c[0].data);
    const xburger = criados.find((d: any) => d.nome === 'X-Burger');
    expect(xburger.precoCentavos).toBe(2990); // "29.90" → 2990
    expect(xburger.disponivel).toBe(true); // disponivelCardapio
    expect(xburger.categoriaId).toBe('gc-Lanches'); // mapeado da categoria criada
    expect(xburger.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: 'PROD-1' },
    ]);

    const refri = criados.find((d: any) => d.nome === 'Refrigerante');
    expect(refri.precoCentavos).toBe(750); // "7.50" → 750
    expect(refri.disponivel).toBe(false); // disponivelCardapio=false
  });

  it('mapeia grupo/opção incl. precoDelta→centavos e de-para da opção', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(payload());
    await service.importar();

    const grupo = prisma.complementoGrupo.create.mock.calls[0][0].data;
    expect(grupo.nome).toBe('Escolha a bebida');
    expect(grupo.min).toBe(1);
    expect(grupo.max).toBe(1);
    expect(grupo.obrigatorio).toBe(true);

    const opcao = prisma.complementoOpcao.create.mock.calls[0][0].data;
    expect(opcao.grupoId).toBe('gg-1');
    expect(opcao.precoCentavosDelta).toBe(500); // "5.00" → 500
    expect(opcao.disponivel).toBe(true);
    expect(opcao.externalRefs).toEqual([
      { sistema: 'regem', codigo_pdv: 'OPC-1' },
    ]);
  });

  it('NUNCA passa tenantId manual em nenhuma escrita Prisma', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(payload());
    await service.importar();
    expect(todasEscritas(prisma)).not.toContain('tenantId');
  });
});

describe('RegemImportService.importar — idempotência (refresh)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('produto já existente por codigo_pdv é ATUALIZADO, não recriado', async () => {
    const { service, prisma, client } = makeService();
    // Só PROD-1 no payload.
    const p = payload();
    p.produtos = [p.produtos[0]];
    client.fetchCatalogo.mockResolvedValue(p);
    // GoGeM já tem um produto com o de-para regem PROD-1.
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'gp-existente',
        externalRefs: [{ sistema: 'regem', codigo_pdv: 'PROD-1' }],
      },
    ]);

    const resumo = await service.importar();

    expect(resumo.produtos).toEqual({
      criados: 0,
      atualizados: 1,
      ignoradosSemCodigo: 0,
    });
    expect(prisma.produto.create).not.toHaveBeenCalled();
    expect(prisma.produto.update).toHaveBeenCalledTimes(1);
    expect(prisma.produto.update.mock.calls[0][0].where).toEqual({
      id: 'gp-existente',
    });
  });

  it('preserva refs não-regem ao atualizar o produto', async () => {
    const { service, prisma, client } = makeService();
    const p = payload();
    p.produtos = [p.produtos[0]];
    client.fetchCatalogo.mockResolvedValue(p);
    prisma.produto.findMany.mockResolvedValue([
      {
        id: 'gp-existente',
        externalRefs: [
          { sistema: 'ifood', codigo_pdv: 'IF-9' },
          { sistema: 'regem', codigo_pdv: 'PROD-1' },
        ],
      },
    ]);

    await service.importar();

    const data = prisma.produto.update.mock.calls[0][0].data;
    expect(data.externalRefs).toEqual([
      { sistema: 'ifood', codigo_pdv: 'IF-9' },
      { sistema: 'regem', codigo_pdv: 'PROD-1' },
    ]);
  });

  it('categoria existente (mesmo nome, case-insensitive) é atualizada, não recriada', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(payload());
    prisma.categoria.findMany.mockResolvedValue([
      { id: 'gc-x', nome: 'lanches' }, // case-insensitive match
    ]);

    const resumo = await service.importar();

    expect(resumo.categorias.criadas).toBe(1); // só Bebidas criada
    expect(resumo.categorias.atualizadas).toBe(1); // Lanches casada
    // X-Burger aponta para a categoria já existente.
    const xburger = prisma.produto.create.mock.calls
      .map((c: any) => c[0].data)
      .find((d: any) => d.nome === 'X-Burger');
    expect(xburger.categoriaId).toBe('gc-x');
  });
});

describe('RegemImportService.importar — reflexo de pausa (Fase 4)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('canal gogem / inativo / esgotado → disponivel=false; ifood não afeta', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue({
      geradoEm: 'x',
      categorias: [{ id: 'rc', nome: 'Cat', ordem: 1 }],
      produtos: [
        {
          id: 'a',
          codigo: 'A',
          nome: 'Pausado canal',
          precoVenda: '10.00',
          categoriaId: 'rc',
          disponivelCardapio: true,
          ativo: true,
          canaisPausados: ['gogem'],
          grupos: [],
        },
        {
          id: 'b',
          codigo: 'B',
          nome: 'Inativo',
          precoVenda: '10.00',
          categoriaId: 'rc',
          disponivelCardapio: true,
          ativo: false,
          grupos: [],
        },
        {
          id: 'c',
          codigo: 'C',
          nome: 'Esgotado',
          precoVenda: '10.00',
          categoriaId: 'rc',
          disponivelCardapio: true,
          ativo: true,
          pausadoEstoque: true,
          grupos: [],
        },
        {
          id: 'd',
          codigo: 'D',
          nome: 'Ok',
          precoVenda: '10.00',
          categoriaId: 'rc',
          disponivelCardapio: true,
          ativo: true,
          canaisPausados: ['ifood'],
          grupos: [],
        },
      ],
    });

    await service.importar();

    const porCodigo: Record<string, any> = {};
    for (const c of prisma.produto.create.mock.calls) {
      const data = (c as any)[0].data;
      porCodigo[data.externalRefs[0].codigo_pdv] = data;
    }
    expect(porCodigo['A'].disponivel).toBe(false); // canal gogem pausado
    expect(porCodigo['B'].disponivel).toBe(false); // inativo
    expect(porCodigo['C'].disponivel).toBe(false); // esgotado (estoque)
    expect(porCodigo['D'].disponivel).toBe(true); // ifood pausado não afeta o totem
  });
});

describe('reaisToCentavos — helper puro', () => {
  it('arredonda reais (string) para centavos inteiros', () => {
    expect(reaisToCentavos('29.90')).toBe(2990);
    expect(reaisToCentavos('0.1')).toBe(10);
    expect(reaisToCentavos('19.99')).toBe(1999);
    expect(reaisToCentavos('12.345')).toBe(1235);
    expect(reaisToCentavos('0.005')).toBe(1);
    expect(reaisToCentavos('100')).toBe(10000);
  });

  it('trata nulo/vazio/inválido como 0', () => {
    expect(reaisToCentavos(null)).toBe(0);
    expect(reaisToCentavos(undefined)).toBe(0);
    expect(reaisToCentavos('')).toBe(0);
    expect(reaisToCentavos('abc')).toBe(0);
  });

  it('aceita number direto', () => {
    expect(reaisToCentavos(29.9)).toBe(2990);
  });
});
