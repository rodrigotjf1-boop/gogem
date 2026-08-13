import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type Aparencia } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CardapioService } from '../cardapio/cardapio.service';
import { AparenciaService } from '../aparencia/aparencia.service';

/** Totais do catálogo publicado (retornados no publicar). */
export interface PublicarTotais {
  categorias: number;
  produtos: number;
  grupos: number;
  opcoes: number;
}

/** Metadados de uma versão (sem o corpo do snapshot). */
export interface VersaoMeta {
  id: string;
  versao: number;
  publishedAt: Date;
  publishedById: string | null;
}

/**
 * CatalogoPublicacaoService — publicação versionada do catálogo (CLAUDE.md §3).
 *
 * Ao publicar, monta um snapshot imutável (árvore completa: categorias +
 * produtos + grupos + opções) a partir do rascunho atual e o congela numa linha
 * de MenuVersion; o totem sincroniza por `versao`.
 *
 * Multi-tenant (CLAUDE.md §2): NENHUM método adiciona `tenantId` à mão — o
 * middleware do Prisma injeta o tenant do contexto e falha fechado sem ele.
 * Dinheiro sempre em centavos (inteiro), nunca float.
 */
@Injectable()
export class CatalogoPublicacaoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cardapios: CardapioService,
    private readonly aparencia: AparenciaService,
  ) {}

  /**
   * Publica o rascunho: monta o snapshot, calcula `versao = max + 1` (começa em
   * 1) e cria uma MenuVersion. Corrida em publicações concorrentes: a `@@unique
   * ([tenantId, versao])` protege a integridade — em colisão (P2002) tentamos
   * mais uma vez com `versao + 1`.
   */
  async publicar(
    publishedById: string | null,
  ): Promise<{ versao: number; publishedAt: Date; totais: PublicarTotais }> {
    const { snapshot, totais } = await this.assembleSnapshot();
    let versao = await this.proximaVersao();

    // Uma retentativa em caso de corrida (P2002 na unique [tenantId, versao]).
    for (let tentativa = 0; tentativa < 2; tentativa++) {
      const data = {
        versao,
        snapshot: snapshot as unknown as Prisma.InputJsonValue,
        publishedById,
      } satisfies Omit<Prisma.MenuVersionUncheckedCreateInput, 'tenantId'>;
      try {
        const created = await this.prisma.menuVersion.create({
          data: data as Prisma.MenuVersionUncheckedCreateInput,
        });
        return {
          versao: created.versao,
          publishedAt: created.publishedAt,
          totais,
        };
      } catch (err) {
        if (isUniqueViolation(err) && tentativa === 0) {
          versao += 1;
          continue;
        }
        throw err;
      }
    }
    // Inalcançável: o laço retorna ou lança. Mantém o TS satisfeito.
    /* istanbul ignore next */
    throw new Error('Falha ao publicar o catálogo (versão em conflito).');
  }

  /** Lista metadados das versões (sem o snapshot), da mais nova para a antiga. */
  listVersoes(): Promise<VersaoMeta[]> {
    return this.prisma.menuVersion.findMany({
      orderBy: { versao: 'desc' },
      select: {
        id: true,
        versao: true,
        publishedAt: true,
        publishedById: true,
      },
    });
  }

  /**
   * Retorna a última versão publicada.
   *
   * `desde` = checagem incremental barata para o totem: se `desde >=` a última
   * versão, responde `{ versao, atualizado: false }` (sem corpo). Caso
   * contrário devolve o snapshot completo com `atualizado: true`. Sem nenhuma
   * versão publicada → 404.
   *
   * NOTE (S2/S3): esta leitura hoje é protegida por JWT. A autenticação do
   * dispositivo/totem (pareamento via `X-Sync-Token`) que de fato guardará o
   * sync do totem é um follow-up — TODO trocar o guard quando existir.
   */
  async getPublicado(desde?: number): Promise<
    | { versao: number; atualizado: false; aparencia: Aparencia }
    | {
        versao: number;
        publishedAt: Date;
        snapshot: Prisma.JsonValue;
        atualizado: true;
        aparencia: Aparencia;
      }
  > {
    const latest = await this.prisma.menuVersion.findFirst({
      orderBy: { versao: 'desc' },
    });
    if (!latest) {
      throw new NotFoundException(
        'Nenhuma versão do catálogo publicada ainda.',
      );
    }
    // A aparência é LIVE (por loja): vai em toda resposta do sync — inclusive
    // quando o catálogo não mudou — para o totem re-tematizar sem re-publicar.
    const aparencia = await this.aparencia.obter();
    if (desde !== undefined && desde >= latest.versao) {
      return { versao: latest.versao, atualizado: false, aparencia };
    }
    return {
      versao: latest.versao,
      publishedAt: latest.publishedAt,
      snapshot: latest.snapshot,
      atualizado: true,
      aparencia,
    };
  }

  /** Próxima versão do tenant: `max(versao) + 1` (1 na primeira publicação). */
  private async proximaVersao(): Promise<number> {
    const agg = await this.prisma.menuVersion.aggregate({
      _max: { versao: true },
    });
    return (agg._max.versao ?? 0) + 1;
  }

  /**
   * Monta o snapshot a partir do rascunho atual (escopado por tenant pelo
   * middleware). Inclui TODOS os produtos (disponíveis ou não — disponibilidade
   * é um campo). Ordena: categorias por ordem,nome; produtos por nome; grupos e
   * opções por ordem,nome.
   */
  private async assembleSnapshot(): Promise<{
    snapshot: CatalogoSnapshot;
    totais: PublicarTotais;
  }> {
    // O totem recebe SEMPRE o cardápio ativo (Fase 3B).
    const cardapioId = await this.cardapios.ativoId();
    const [categorias, produtos] = await Promise.all([
      this.prisma.categoria.findMany({
        where: { cardapioId },
        orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
      }),
      this.prisma.produto.findMany({
        where: { cardapioId },
        orderBy: { nome: 'asc' },
        include: {
          // Etapas via vínculo (reutilizáveis), na ordem do produto.
          complementos: {
            orderBy: { ordem: 'asc' },
            include: {
              grupo: {
                include: {
                  opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] },
                },
              },
            },
          },
        },
      }),
    ]);

    // Upsell "Peça também" (F2): sugestões por produto. Só publica sugeridos que
    // existem no cardápio ativo (evita refs órfãs no totem), na ordem definida.
    const idsNoCardapio = new Set(produtos.map((p) => p.id));
    const upsellRows = await this.prisma.produtoUpsell.findMany({
      where: { produtoId: { in: [...idsNoCardapio] } },
      orderBy: { ordem: 'asc' },
      select: { produtoId: true, sugeridoId: true },
    });
    const upsellPorProduto = new Map<string, string[]>();
    for (const r of upsellRows) {
      if (!idsNoCardapio.has(r.sugeridoId)) continue;
      const lista = upsellPorProduto.get(r.produtoId) ?? [];
      lista.push(r.sugeridoId);
      upsellPorProduto.set(r.produtoId, lista);
    }

    // Categorias pausadas somem do totem — elas E seus produtos. Calculamos as
    // listas "ativas" uma vez e derivamos snapshot + totais delas (senão os
    // totais contariam itens que não foram publicados).
    const pausadaIds = new Set(
      categorias.filter((c) => c.pausada).map((c) => c.id),
    );
    const categoriasAtivas = categorias.filter((c) => !c.pausada);
    const produtosAtivos = produtos.filter(
      (p) => !(p.categoriaId && pausadaIds.has(p.categoriaId)),
    );

    const snapshot: CatalogoSnapshot = {
      geradoEm: new Date().toISOString(),
      categorias: categoriasAtivas.map((c) => ({
        id: c.id,
        nome: c.nome,
        ordem: c.ordem,
        imagemUrl: c.imagemUrl,
        emoji: c.emoji,
        cor: c.cor,
      })),
      produtos: produtosAtivos.map((p) => ({
        id: p.id,
        nome: p.nome,
        descricao: p.descricao,
        precoCentavos: p.precoCentavos,
        disponivel: p.disponivel,
        imagemUrl: p.imagemUrl,
        selo: p.selo,
        categoriaId: p.categoriaId,
        externalRefs: p.externalRefs,
        upsell: upsellPorProduto.get(p.id) ?? [],
        // Shape do totem inalterado: `grupos` (agora resolvidos do vínculo).
        grupos: p.complementos.map((pc) => ({
          id: pc.grupo.id,
          nome: pc.grupo.nome,
          min: pc.grupo.min,
          max: pc.grupo.max,
          obrigatorio: pc.grupo.obrigatorio,
          ordem: pc.ordem,
          opcoes: pc.grupo.opcoes.map((o) => ({
            id: o.id,
            nome: o.nome,
            precoCentavosDelta: o.precoCentavosDelta,
            disponivel: o.disponivel,
            imagemUrl: o.imagemUrl,
            ordem: o.ordem,
            externalRefs: o.externalRefs,
          })),
        })),
      })),
    };

    const grupos = produtosAtivos.reduce(
      (n, p) => n + p.complementos.length,
      0,
    );
    const opcoes = produtosAtivos.reduce(
      (n, p) =>
        n + p.complementos.reduce((m, pc) => m + pc.grupo.opcoes.length, 0),
      0,
    );

    return {
      snapshot,
      totais: {
        categorias: categoriasAtivas.length,
        produtos: produtosAtivos.length,
        grupos,
        opcoes,
      },
    };
  }
}

/** Detecta a violação de unicidade do Prisma (P2002). */
function isUniqueViolation(err: unknown): boolean {
  return (
    err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002'
  );
}

// --- Shape do snapshot (§3) -------------------------------------------------

interface CatalogoSnapshot {
  geradoEm: string;
  categorias: Array<{
    id: string;
    nome: string;
    ordem: number;
    imagemUrl: string | null;
    emoji: string | null;
    cor: string | null;
  }>;
  produtos: Array<{
    id: string;
    nome: string;
    descricao: string | null;
    precoCentavos: number;
    disponivel: boolean;
    imagemUrl: string | null;
    /** Selo de destaque no card (F4) — ex.: "Mais vendido". */
    selo: string | null;
    categoriaId: string | null;
    externalRefs: Prisma.JsonValue;
    /** IDs de produtos sugeridos (upsell "Peça também", F2). */
    upsell: string[];
    grupos: Array<{
      id: string;
      nome: string;
      min: number;
      max: number | null;
      obrigatorio: boolean;
      ordem: number;
      opcoes: Array<{
        id: string;
        nome: string;
        precoCentavosDelta: number;
        disponivel: boolean;
        imagemUrl: string | null;
        ordem: number;
        externalRefs: Prisma.JsonValue;
      }>;
    }>;
  }>;
}
