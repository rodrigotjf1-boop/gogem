import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  RegemCatalogClient,
  type RegemGrupo,
  type RegemProduto,
} from './regem-catalog.client';
import { reaisToCentavos } from './reais-to-centavos';

/**
 * RegemImportService — capstone da integração Regem↔GoGeM (fatia 3).
 *
 * Puxa o catálogo do Regem e constrói/atualiza o catálogo-rascunho do GoGeM.
 *
 * Multi-tenant (CLAUDE.md §2): NENHUM método adiciona `tenantId` à mão — o
 * middleware `$use` do PrismaService injeta o tenant do contexto (a rota de
 * import é JWT-guarded, então o contexto sempre existe). Todos os
 * reads/writes são chamadas Prisma normais.
 *
 * De-para PDV (§4): a idempotência de produto usa a chave
 * `(sistema='regem', codigo_pdv=produto.codigo)`; grupos e opções casam por
 * `(produtoId, nome)` e `(grupoId, nome)`.
 *
 * Semântica v1: **aditivo/refresh** — cria o que falta e atualiza o que já
 * existe; NÃO deleta itens do GoGeM ausentes no Regem.
 */

/** Uma referência de de-para PDV persistida no Json (§4). */
interface ExternalRef {
  sistema: string;
  codigo_pdv: string;
  loja?: string;
  [k: string]: unknown;
}

/** Resumo do que o import criou/atualizou. */
export interface RegemImportResumo {
  geradoEm: string;
  categorias: { criadas: number; atualizadas: number };
  produtos: {
    criados: number;
    atualizados: number;
    ignoradosSemCodigo: number;
  };
  grupos: { criados: number; atualizados: number };
  opcoes: { criados: number; atualizados: number };
}

@Injectable()
export class RegemImportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly client: RegemCatalogClient,
  ) {}

  /** Executa o import para o tenant do contexto atual. */
  async importar(): Promise<RegemImportResumo> {
    const catalogo = await this.client.fetchCatalogo();

    const resumo: RegemImportResumo = {
      geradoEm: catalogo.geradoEm,
      categorias: { criadas: 0, atualizadas: 0 },
      produtos: { criados: 0, atualizados: 0, ignoradosSemCodigo: 0 },
      grupos: { criados: 0, atualizados: 0 },
      opcoes: { criados: 0, atualizados: 0 },
    };

    const categoriaMap = await this.importCategorias(
      catalogo.categorias,
      resumo,
    );
    const produtoPorCodigo = await this.carregarProdutosPorCodigo();

    for (const rp of catalogo.produtos) {
      const codigo = (rp.codigo ?? '').trim();
      if (!codigo) {
        resumo.produtos.ignoradosSemCodigo += 1;
        continue;
      }
      const gogemProdutoId = await this.upsertProduto(
        rp,
        codigo,
        categoriaMap,
        produtoPorCodigo,
        resumo,
      );
      await this.importGruposOpcoes(gogemProdutoId, rp.grupos, resumo);
    }

    return resumo;
  }

  /**
   * Casa categorias por `nome` (trim, case-insensitive) no tenant; cria as
   * ausentes (ordem do Regem) e atualiza a ordem das existentes. Retorna o
   * mapa `regemCategoriaId → gogemCategoriaId`.
   */
  private async importCategorias(
    categorias: { id: string; nome: string; ordem: number }[],
    resumo: RegemImportResumo,
  ): Promise<Map<string, string>> {
    const existentes = await this.prisma.categoria.findMany();
    const porNome = new Map<string, { id: string }>();
    for (const c of existentes) porNome.set(normalizar(c.nome), { id: c.id });

    const map = new Map<string, string>();
    for (const rc of categorias) {
      const chave = normalizar(rc.nome);
      const existente = porNome.get(chave);
      if (existente) {
        await this.prisma.categoria.update({
          where: { id: existente.id },
          data: { ordem: rc.ordem ?? 0 },
        });
        resumo.categorias.atualizadas += 1;
        map.set(rc.id, existente.id);
      } else {
        const data = {
          nome: rc.nome,
          ordem: rc.ordem ?? 0,
        } satisfies Omit<Prisma.CategoriaUncheckedCreateInput, 'tenantId'>;
        const criada = await this.prisma.categoria.create({
          data: data as Prisma.CategoriaUncheckedCreateInput,
        });
        resumo.categorias.criadas += 1;
        porNome.set(chave, { id: criada.id });
        map.set(rc.id, criada.id);
      }
    }
    return map;
  }

  /** Carrega TODOS os produtos do tenant e indexa por `codigo_pdv` do de-para regem. */
  private async carregarProdutosPorCodigo(): Promise<
    Map<string, { id: string; externalRefs: ExternalRef[] }>
  > {
    const produtos = await this.prisma.produto.findMany();
    const map = new Map<string, { id: string; externalRefs: ExternalRef[] }>();
    for (const p of produtos) {
      const refs = lerRefs(p.externalRefs);
      const regemRef = refs.find((r) => r.sistema === 'regem' && r.codigo_pdv);
      if (regemRef) {
        map.set(regemRef.codigo_pdv, { id: p.id, externalRefs: refs });
      }
    }
    return map;
  }

  /**
   * Upsert de um produto pela chave de-para `(regem, codigo)`. Cria se ausente,
   * senão atualiza. Preserva refs não-regem ao atualizar. Retorna o id GoGeM.
   */
  private async upsertProduto(
    rp: RegemProduto,
    codigo: string,
    categoriaMap: Map<string, string>,
    produtoPorCodigo: Map<string, { id: string; externalRefs: ExternalRef[] }>,
    resumo: RegemImportResumo,
  ): Promise<string> {
    const precoCentavos = reaisToCentavos(rp.precoVenda);
    const disponivel = !!rp.disponivelCardapio;
    const categoriaId = rp.categoriaId
      ? (categoriaMap.get(rp.categoriaId) ?? null)
      : null;

    const existente = produtoPorCodigo.get(codigo);
    if (existente) {
      const externalRefs = upsertRegemRef(existente.externalRefs, codigo);
      await this.prisma.produto.update({
        where: { id: existente.id },
        data: {
          nome: rp.nome,
          descricao: rp.descricao ?? null,
          precoCentavos,
          disponivel,
          categoriaId,
          externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
        },
      });
      resumo.produtos.atualizados += 1;
      return existente.id;
    }

    const externalRefs = upsertRegemRef([], codigo);
    const data = {
      nome: rp.nome,
      descricao: rp.descricao ?? null,
      precoCentavos,
      disponivel,
      categoriaId,
      externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
    } satisfies Omit<Prisma.ProdutoUncheckedCreateInput, 'tenantId'>;
    const criado = await this.prisma.produto.create({
      data: data as Prisma.ProdutoUncheckedCreateInput,
    });
    resumo.produtos.criados += 1;
    // Indexa para não recriar caso o mesmo codigo apareça duplicado no payload.
    produtoPorCodigo.set(codigo, { id: criado.id, externalRefs });
    return criado.id;
  }

  /**
   * Importa grupos (casados por `(produtoId, nome)`) e suas opções (casadas por
   * `(grupoId, nome)`) de um produto já materializado no GoGeM.
   */
  private async importGruposOpcoes(
    produtoId: string,
    grupos: RegemGrupo[],
    resumo: RegemImportResumo,
  ): Promise<void> {
    const gruposExistentes = await this.prisma.complementoGrupo.findMany({
      where: { produtoId },
    });
    const grupoPorNome = new Map<string, { id: string }>();
    for (const g of gruposExistentes) {
      grupoPorNome.set(normalizar(g.nome), { id: g.id });
    }

    for (const rg of grupos ?? []) {
      let grupoId: string;
      const existente = grupoPorNome.get(normalizar(rg.nome));
      if (existente) {
        await this.prisma.complementoGrupo.update({
          where: { id: existente.id },
          data: {
            nome: rg.nome,
            min: rg.min ?? 0,
            max: rg.max ?? null,
            obrigatorio: rg.obrigatorio ?? false,
            ordem: rg.ordem ?? 0,
          },
        });
        resumo.grupos.atualizados += 1;
        grupoId = existente.id;
      } else {
        const data = {
          produtoId,
          nome: rg.nome,
          min: rg.min ?? 0,
          max: rg.max ?? null,
          obrigatorio: rg.obrigatorio ?? false,
          ordem: rg.ordem ?? 0,
        } satisfies Omit<
          Prisma.ComplementoGrupoUncheckedCreateInput,
          'tenantId'
        >;
        const criado = await this.prisma.complementoGrupo.create({
          data: data as Prisma.ComplementoGrupoUncheckedCreateInput,
        });
        resumo.grupos.criados += 1;
        grupoId = criado.id;
        grupoPorNome.set(normalizar(rg.nome), { id: grupoId });
      }
      await this.importOpcoes(grupoId, rg, resumo);
    }
  }

  /** Upsert das opções de um grupo, casadas por `(grupoId, nome)`. */
  private async importOpcoes(
    grupoId: string,
    rg: RegemGrupo,
    resumo: RegemImportResumo,
  ): Promise<void> {
    const opcoesExistentes = await this.prisma.complementoOpcao.findMany({
      where: { grupoId },
    });
    const opcaoPorNome = new Map<string, { id: string }>();
    for (const o of opcoesExistentes) {
      opcaoPorNome.set(normalizar(o.nome), { id: o.id });
    }

    for (const ro of rg.opcoes ?? []) {
      const precoCentavosDelta = reaisToCentavos(ro.precoDelta);
      const externalRefs: ExternalRef[] = ro.codigoPdv
        ? [{ sistema: 'regem', codigo_pdv: ro.codigoPdv }]
        : [];
      const existente = opcaoPorNome.get(normalizar(ro.nome));
      if (existente) {
        await this.prisma.complementoOpcao.update({
          where: { id: existente.id },
          data: {
            nome: ro.nome,
            precoCentavosDelta,
            ordem: ro.ordem ?? 0,
            externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
          },
        });
        resumo.opcoes.atualizados += 1;
      } else {
        const data = {
          grupoId,
          nome: ro.nome,
          precoCentavosDelta,
          disponivel: true,
          ordem: ro.ordem ?? 0,
          externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
        } satisfies Omit<
          Prisma.ComplementoOpcaoUncheckedCreateInput,
          'tenantId'
        >;
        await this.prisma.complementoOpcao.create({
          data: data as Prisma.ComplementoOpcaoUncheckedCreateInput,
        });
        resumo.opcoes.criados += 1;
        opcaoPorNome.set(normalizar(ro.nome), { id: 'novo' });
      }
    }
  }
}

/** Normaliza um nome para casamento: trim + lower-case. */
function normalizar(nome: string): string {
  return (nome ?? '').trim().toLowerCase();
}

/** Lê o Json de `externalRefs` como array de refs (defensivo). */
function lerRefs(raw: unknown): ExternalRef[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (r): r is ExternalRef =>
      !!r &&
      typeof r === 'object' &&
      typeof (r as Record<string, unknown>).sistema === 'string' &&
      typeof (r as Record<string, unknown>).codigo_pdv === 'string',
  );
}

/**
 * Garante um único ref regem com o `codigo_pdv` informado, preservando os refs
 * de outros sistemas (não duplica; não clobbera não-regem).
 */
function upsertRegemRef(
  existing: ExternalRef[],
  codigoPdv: string,
): ExternalRef[] {
  const naoRegem = existing.filter((r) => r.sistema !== 'regem');
  return [...naoRegem, { sistema: 'regem', codigo_pdv: codigoPdv }];
}
