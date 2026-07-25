import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

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
  constructor(private readonly prisma: PrismaService) {}

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
    | { versao: number; atualizado: false }
    | {
        versao: number;
        publishedAt: Date;
        snapshot: Prisma.JsonValue;
        atualizado: true;
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
    if (desde !== undefined && desde >= latest.versao) {
      return { versao: latest.versao, atualizado: false };
    }
    return {
      versao: latest.versao,
      publishedAt: latest.publishedAt,
      snapshot: latest.snapshot,
      atualizado: true,
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
    const [categorias, produtos] = await Promise.all([
      this.prisma.categoria.findMany({
        orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
      }),
      this.prisma.produto.findMany({
        orderBy: { nome: 'asc' },
        include: {
          grupos: {
            orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
            include: {
              opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] },
            },
          },
        },
      }),
    ]);

    const snapshot: CatalogoSnapshot = {
      geradoEm: new Date().toISOString(),
      categorias: categorias.map((c) => ({
        id: c.id,
        nome: c.nome,
        ordem: c.ordem,
      })),
      produtos: produtos.map((p) => ({
        id: p.id,
        nome: p.nome,
        descricao: p.descricao,
        precoCentavos: p.precoCentavos,
        disponivel: p.disponivel,
        categoriaId: p.categoriaId,
        externalRefs: p.externalRefs,
        grupos: p.grupos.map((g) => ({
          id: g.id,
          nome: g.nome,
          min: g.min,
          max: g.max,
          obrigatorio: g.obrigatorio,
          ordem: g.ordem,
          opcoes: g.opcoes.map((o) => ({
            id: o.id,
            nome: o.nome,
            precoCentavosDelta: o.precoCentavosDelta,
            disponivel: o.disponivel,
            ordem: o.ordem,
            externalRefs: o.externalRefs,
          })),
        })),
      })),
    };

    const grupos = produtos.reduce((n, p) => n + p.grupos.length, 0);
    const opcoes = produtos.reduce(
      (n, p) => n + p.grupos.reduce((m, g) => m + g.opcoes.length, 0),
      0,
    );

    return {
      snapshot,
      totais: {
        categorias: categorias.length,
        produtos: produtos.length,
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
  categorias: Array<{ id: string; nome: string; ordem: number }>;
  produtos: Array<{
    id: string;
    nome: string;
    descricao: string | null;
    precoCentavos: number;
    disponivel: boolean;
    categoriaId: string | null;
    externalRefs: Prisma.JsonValue;
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
        ordem: number;
        externalRefs: Prisma.JsonValue;
      }>;
    }>;
  }>;
}
