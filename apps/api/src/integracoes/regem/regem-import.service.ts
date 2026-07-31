import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CardapioService } from '../../cardapio/cardapio.service';
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
    private readonly cardapios: CardapioService,
  ) {}

  /**
   * Executa o import para o tenant do contexto. `cardapioId` = cardápio-alvo
   * (Fase 3B): permite importar para o cardápio em preparação (migração de
   * sistema) sem tocar o ativo; ausente = cardápio ativo.
   */
  async importar(cardapioId?: string): Promise<RegemImportResumo> {
    const alvo = await this.cardapios.resolverAlvo(cardapioId);
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
      alvo,
    );
    const produtoPorCodigo = await this.carregarProdutosPorCodigo(alvo);

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
        alvo,
      );
      await this.importGruposOpcoes(gogemProdutoId, rp.grupos, resumo);
    }

    return resumo;
  }

  /**
   * Sincroniza do Regem apenas os produtos JÁ LINKADOS (mesmo código PDV) — o
   * Regem age como "segundo admin": edições de preço, nome, descrição e
   * pausa/disponibilidade propagam ao GoGeM. NÃO cria produtos novos (isso é o
   * `importar`) nem toca campos só-GoGeM (selo, upsell, imagem, categoria).
   * Atualiza apenas o que mudou; devolve quantos foram alterados (o chamador
   * republica só se `alterados > 0`).
   */
  async sincronizarLinkados(
    cardapioId?: string,
  ): Promise<{ verificados: number; alterados: number }> {
    const alvo = await this.cardapios.resolverAlvo(cardapioId);
    const catalogo = await this.client.fetchCatalogo();

    // Estado desejado por código PDV (a partir do Regem).
    const desejado = new Map<
      string,
      {
        precoCentavos: number;
        disponivel: boolean;
        nome: string;
        descricao: string | null;
      }
    >();
    for (const rp of catalogo.produtos) {
      const codigo = (rp.codigo ?? '').trim();
      if (!codigo) continue;
      desejado.set(codigo, {
        precoCentavos: reaisToCentavos(rp.precoVenda),
        disponivel: disponivelNoGogem(rp),
        nome: rp.nome,
        descricao: rp.descricao ?? null,
      });
    }

    // Produtos GoGeM do cardápio-alvo, com os campos que podem mudar.
    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId: alvo },
      select: {
        id: true,
        nome: true,
        descricao: true,
        precoCentavos: true,
        disponivel: true,
        externalRefs: true,
      },
    });

    let verificados = 0;
    let alterados = 0;
    for (const p of produtos) {
      const codigo = codigoRegem(p.externalRefs);
      if (!codigo) continue;
      const alvoRegem = desejado.get(codigo);
      if (!alvoRegem) continue; // produto não veio no catálogo do Regem
      verificados += 1;

      const patch: Record<string, unknown> = {};
      if (alvoRegem.precoCentavos !== p.precoCentavos)
        patch.precoCentavos = alvoRegem.precoCentavos;
      if (alvoRegem.disponivel !== p.disponivel)
        patch.disponivel = alvoRegem.disponivel;
      if (alvoRegem.nome !== p.nome) patch.nome = alvoRegem.nome;
      if ((alvoRegem.descricao ?? null) !== (p.descricao ?? null))
        patch.descricao = alvoRegem.descricao;

      if (Object.keys(patch).length) {
        await this.prisma.produto.update({ where: { id: p.id }, data: patch });
        alterados += 1;
      }
    }
    return { verificados, alterados };
  }

  /**
   * Casa categorias por `nome` (trim, case-insensitive) no tenant; cria as
   * ausentes (ordem do Regem) e atualiza a ordem das existentes. Retorna o
   * mapa `regemCategoriaId → gogemCategoriaId`.
   */
  private async importCategorias(
    categorias: { id: string; nome: string; ordem: number }[],
    resumo: RegemImportResumo,
    cardapioId: string,
  ): Promise<Map<string, string>> {
    const existentes = await this.prisma.categoria.findMany({
      where: { cardapioId },
    });
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
          cardapioId,
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

  /** Carrega os produtos do cardápio-alvo e indexa por `codigo_pdv` (de-para regem). */
  private async carregarProdutosPorCodigo(
    cardapioId: string,
  ): Promise<Map<string, { id: string; externalRefs: ExternalRef[] }>> {
    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId },
    });
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
    cardapioId: string,
  ): Promise<string> {
    const precoCentavos = reaisToCentavos(rp.precoVenda);
    const disponivel = disponivelNoGogem(rp);
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
      cardapioId,
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
   * Importa etapas e opções de um produto. Etapas são REUTILIZÁVEIS: casa por
   * nome entre as JÁ VINCULADAS ao produto (via `ProdutoComplemento`); cria uma
   * etapa nova + vínculo quando não existe. Opções casam por `(grupoId, nome)`.
   */
  private async importGruposOpcoes(
    produtoId: string,
    grupos: RegemGrupo[],
    resumo: RegemImportResumo,
  ): Promise<void> {
    const links = await this.prisma.produtoComplemento.findMany({
      where: { produtoId },
      include: { grupo: true },
    });
    const grupoPorNome = new Map<string, { id: string }>();
    for (const l of links) {
      grupoPorNome.set(normalizar(l.grupo.nome), { id: l.grupo.id });
    }
    let proximaOrdem = links.length;

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
          },
        });
        resumo.grupos.atualizados += 1;
        grupoId = existente.id;
      } else {
        const grupoData = {
          nome: rg.nome,
          min: rg.min ?? 0,
          max: rg.max ?? null,
          obrigatorio: rg.obrigatorio ?? false,
        } satisfies Omit<
          Prisma.ComplementoGrupoUncheckedCreateInput,
          'tenantId'
        >;
        const criado = await this.prisma.complementoGrupo.create({
          data: grupoData as Prisma.ComplementoGrupoUncheckedCreateInput,
        });
        const linkData = {
          produtoId,
          grupoId: criado.id,
          ordem: rg.ordem ?? proximaOrdem++,
        } satisfies Omit<
          Prisma.ProdutoComplementoUncheckedCreateInput,
          'tenantId'
        >;
        await this.prisma.produtoComplemento.create({
          data: linkData as Prisma.ProdutoComplementoUncheckedCreateInput,
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

/** Canais do Regem que representam o totem/GoGeM (pausa reflete no GoGeM). */
const CANAIS_GOGEM = ['gogem', 'totem'];

/**
 * Disponibilidade do produto no GoGeM a partir do estado do Regem (Fase 4,
 * Regem→GoGeM): indisponível se inativo, fora do cardápio, esgotado (estoque)
 * ou com o canal do totem pausado. Pausar no Regem some do totem no próximo sync.
 */
export function disponivelNoGogem(rp: RegemProduto): boolean {
  if (rp.ativo === false) return false;
  if (!rp.disponivelCardapio) return false;
  if (rp.pausadoEstoque === true) return false;
  const canais = Array.isArray(rp.canaisPausados)
    ? rp.canaisPausados.map((c) => String(c).toLowerCase())
    : [];
  if (canais.some((c) => CANAIS_GOGEM.includes(c))) return false;
  return true;
}

/** Normaliza um nome para casamento: trim + lower-case. */
function normalizar(nome: string): string {
  return (nome ?? '').trim().toLowerCase();
}

/** Código PDV do de-para regem (ou null) a partir do Json de externalRefs. */
function codigoRegem(raw: unknown): string | null {
  const ref = lerRefs(raw).find((r) => r.sistema === 'regem' && r.codigo_pdv);
  return ref ? ref.codigo_pdv.trim() || null : null;
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
