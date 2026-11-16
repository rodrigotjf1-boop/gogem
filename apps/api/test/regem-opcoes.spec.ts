import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RegemImportService } from '../src/integracoes/regem/regem-import.service';
import type { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import type { CardapioService } from '../src/cardapio/cardapio.service';
import type { PrismaService } from '../src/prisma/prisma.service';

/**
 * ERR-040 — o "Importar catálogo" dava 500 ("Record to update not found") num grupo do Regem com duas opções de
 * MESMO nome e códigos diferentes (dois "Lanche 07"): a opção criada era anotada com o id falso 'novo', e a segunda
 * virava `update` dele. E, casando só pelo nome, as duas viravam uma no GoGeM. Agora: id do Regem → código → nome,
 * cada opção do GoGeM com um par só.
 */

function makeService() {
  let n = 0;
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
        id: 'gp-novo',
        ...data,
      })),
      update: vi.fn().mockResolvedValue({}),
    },
    complementoGrupo: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: 'gg-novo' }),
      update: vi.fn().mockResolvedValue({}),
    },
    produtoComplemento: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: 'pc-1' }),
    },
    complementoOpcao: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockImplementation(async ({ data }: any) => ({
        id: `go-criada-${++n}`,
        ...data,
      })),
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
  return { service, prisma, client };
}

/** Um produto do Regem com um grupo e as opções dadas. */
const catalogo = (opcoes: unknown[]) => ({
  geradoEm: 'x',
  categorias: [],
  produtos: [
    {
      id: 'rp-combo',
      codigo: '900',
      nome: 'Combo da casa',
      descricao: null,
      precoVenda: '80.00',
      categoriaId: null,
      disponivelCardapio: true,
      disponivelBalcao: true,
      ativo: true,
      grupos: [
        {
          id: 'rg-1',
          nome: 'Escolha os lanches',
          min: 1,
          max: 2,
          obrigatorio: true,
          ordem: 1,
          opcoes,
        },
      ],
    },
  ],
});

const opcao = (
  id: string | undefined,
  nome: string,
  codigoPdv: string | null,
  ordem: number,
) => ({
  ...(id ? { id } : {}),
  nome,
  precoDelta: '0',
  codigoPdv,
  ordem,
});

/** O GoGeM já tem o grupo ligado ao produto, com estas opções. */
function comGrupoExistente(
  prisma: ReturnType<typeof makeService>['prisma'],
  opcoes: unknown[],
) {
  prisma.produto.findMany.mockResolvedValue([
    {
      id: 'gp-combo',
      externalRefs: [
        { sistema: 'regem', codigo_pdv: '900', regem_id: 'rp-combo' },
      ],
    },
  ]);
  prisma.produtoComplemento.findMany.mockResolvedValue([
    { grupo: { id: 'gg-1', nome: 'Escolha os lanches' } },
  ]);
  prisma.complementoOpcao.findMany.mockResolvedValue(opcoes);
}

describe('importar — opções de mesmo nome no mesmo grupo (ERR-040)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('grupo novo com dois "Lanche 07" de códigos diferentes: cria as DUAS, sem update de id falso', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([
        opcao('ro-a', 'Lanche 07', 'C-840', 1),
        opcao('ro-b', 'Lanche 07', 'C-843', 2),
      ]),
    );

    const resumo = await service.importar();

    expect(prisma.complementoOpcao.update).not.toHaveBeenCalled();
    expect(prisma.complementoOpcao.create).toHaveBeenCalledTimes(2);
    const refs = prisma.complementoOpcao.create.mock.calls.map(
      (c: any) => c[0].data.externalRefs,
    );
    expect(refs).toEqual([
      [{ sistema: 'regem', codigo_pdv: 'C-840', regem_id: 'ro-a' }],
      [{ sistema: 'regem', codigo_pdv: 'C-843', regem_id: 'ro-b' }],
    ]);
    expect(resumo.opcoes).toEqual({ criados: 2, atualizados: 0 });
  });

  it('a importação que parou no meio: a opção que já existe casa pelo CÓDIGO e a outra nasce', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([
        opcao('ro-a', 'Lanche 07', 'C-840', 1),
        opcao('ro-b', 'Lanche 07', 'C-843', 2),
      ]),
    );
    // A de 15/11 criou só a primeira (sem id do Regem, como era).
    comGrupoExistente(prisma, [
      {
        id: 'go-840',
        nome: 'Lanche 07',
        externalRefs: [{ sistema: 'regem', codigo_pdv: 'C-840' }],
      },
    ]);

    await service.importar();

    expect(prisma.complementoOpcao.update).toHaveBeenCalledTimes(1);
    expect(prisma.complementoOpcao.update.mock.calls[0][0].where).toEqual({
      id: 'go-840',
    });
    expect(
      prisma.complementoOpcao.update.mock.calls[0][0].data.externalRefs,
    ).toEqual([{ sistema: 'regem', codigo_pdv: 'C-840', regem_id: 'ro-a' }]);
    expect(prisma.complementoOpcao.create).toHaveBeenCalledTimes(1);
    expect(
      prisma.complementoOpcao.create.mock.calls[0][0].data.externalRefs,
    ).toEqual([{ sistema: 'regem', codigo_pdv: 'C-843', regem_id: 'ro-b' }]);
  });

  it('o código vence o nome mesmo vindo DEPOIS na lista: a de código novo não toma o par da outra', async () => {
    const { service, prisma, client } = makeService();
    // A primeira do Regem tem código que o GoGeM não conhece; a segunda é a que o GoGeM já tem (C-840).
    client.fetchCatalogo.mockResolvedValue(
      catalogo([
        opcao('ro-novo', 'Lanche 07', 'C-999', 1),
        opcao('ro-a', 'Lanche 07', 'C-840', 2),
      ]),
    );
    comGrupoExistente(prisma, [
      {
        id: 'go-840',
        nome: 'Lanche 07',
        externalRefs: [{ sistema: 'regem', codigo_pdv: 'C-840' }],
      },
    ]);

    await service.importar();

    expect(prisma.complementoOpcao.update).toHaveBeenCalledTimes(1);
    expect(prisma.complementoOpcao.update.mock.calls[0][0].where).toEqual({
      id: 'go-840',
    });
    expect(
      prisma.complementoOpcao.update.mock.calls[0][0].data.externalRefs[0]
        .codigo_pdv,
    ).toBe('C-840');
    expect(
      prisma.complementoOpcao.create.mock.calls[0][0].data.externalRefs[0]
        .codigo_pdv,
    ).toBe('C-999');
  });

  it('pelo id do Regem: o código trocado no Regem acompanha na MESMA opção', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([opcao('ro-a', 'Lanche sete', 'C-77', 1)]),
    );
    comGrupoExistente(prisma, [
      {
        id: 'go-840',
        nome: 'Lanche 07',
        externalRefs: [
          { sistema: 'regem', codigo_pdv: 'C-840', regem_id: 'ro-a' },
        ],
      },
    ]);

    await service.importar();

    expect(prisma.complementoOpcao.create).not.toHaveBeenCalled();
    expect(prisma.complementoOpcao.update.mock.calls[0][0]).toMatchObject({
      where: { id: 'go-840' },
      data: {
        nome: 'Lanche sete',
        externalRefs: [
          { sistema: 'regem', codigo_pdv: 'C-77', regem_id: 'ro-a' },
        ],
      },
    });
  });

  it('opção sem código (informativa) segue casando pelo nome', async () => {
    const { service, prisma, client } = makeService();
    client.fetchCatalogo.mockResolvedValue(
      catalogo([opcao('ro-s', 'Sem molho', null, 1)]),
    );
    comGrupoExistente(prisma, [
      { id: 'go-s', nome: 'sem molho ', externalRefs: [] },
    ]);

    await service.importar();

    expect(prisma.complementoOpcao.create).not.toHaveBeenCalled();
    expect(prisma.complementoOpcao.update.mock.calls[0][0]).toMatchObject({
      where: { id: 'go-s' },
      data: { externalRefs: [] },
    });
  });
});
