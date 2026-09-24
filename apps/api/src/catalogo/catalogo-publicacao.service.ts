import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type Aparencia } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CardapioService } from '../cardapio/cardapio.service';
import { AparenciaService } from '../aparencia/aparencia.service';
import { RegemConfigResolver } from '../integracoes/regem/regem-config.resolver';
import { codigoPdvRegem } from '../common/codigo-pdv';

/** Totais do catálogo publicado (retornados no publicar). */
export interface PublicarTotais {
  categorias: number;
  produtos: number;
  grupos: number;
  opcoes: number;
}

/**
 * O que ficou FORA da versão publicada, e por quê. Só existe em loja integrada ao Regem: lá
 * a venda chega ao Regem pelo código PDV, e o que não tem código não tem como ser vendido.
 */
export interface PublicarAvisos {
  /** Produtos sem código PDV — não entram no totem até ganharem o código. */
  produtosSemCodigo: Array<{ id: string; nome: string }>;
  /**
   * Opções PAGAS sem código PDV — saem do totem: o Regem recusaria a venda (o pagamento
   * incluiria um valor que ele não conhece). Opção GRÁTIS sem código fica, e o totem a manda
   * como observação do item ("sem cebola").
   */
  opcoesPagasSemCodigo: Array<{ id: string; nome: string }>;
}

/**
 * Disponibilidade AO VIVO, por cima do retrato publicado: pausar um produto (ou categoria, ou
 * opção) no painel chega ao totem no próximo sync, sem publicar — publicar levaria junto
 * todo o rascunho que o gerente ainda não quis publicar.
 */
export interface DisponibilidadeAoVivo {
  produtosIndisponiveis: string[];
  categoriasPausadas: string[];
  opcoesIndisponiveis: string[];
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
    private readonly regem: RegemConfigResolver,
  ) {}

  /**
   * Publica o rascunho: monta o snapshot, calcula `versao = max + 1` (começa em
   * 1) e cria uma MenuVersion. Corrida em publicações concorrentes: a `@@unique
   * ([tenantId, versao])` protege a integridade — em colisão (P2002) tentamos
   * mais uma vez com `versao + 1`.
   */
  async publicar(publishedById: string | null): Promise<{
    versao: number;
    publishedAt: Date;
    totais: PublicarTotais;
    avisos: PublicarAvisos;
  }> {
    const { snapshot, totais, avisos } = await this.assembleSnapshot();
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
          avisos,
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
    | {
        versao: number;
        atualizado: false;
        aparencia: Aparencia;
        disponibilidade: DisponibilidadeAoVivo;
      }
    | {
        versao: number;
        publishedAt: Date;
        snapshot: Prisma.JsonValue;
        atualizado: true;
        aparencia: Aparencia;
        disponibilidade: DisponibilidadeAoVivo;
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
    // A aparência e a disponibilidade são LIVE: vão em toda resposta do sync —
    // inclusive quando o catálogo não mudou — para o totem re-tematizar e tirar da
    // venda o que foi pausado, sem re-publicar.
    const [aparencia, disponibilidade] = await Promise.all([
      this.aparencia.obter(),
      this.disponibilidadeAoVivo(),
    ]);
    if (desde !== undefined && desde >= latest.versao) {
      return {
        versao: latest.versao,
        atualizado: false,
        aparencia,
        disponibilidade,
      };
    }
    return {
      versao: latest.versao,
      publishedAt: latest.publishedAt,
      snapshot: latest.snapshot,
      atualizado: true,
      aparencia,
      disponibilidade,
    };
  }

  /**
   * O que está pausado AGORA no cardápio ativo (ERR-017). Só ids — o totem aplica por cima
   * do retrato publicado: o que está aqui sai da venda; o que NÃO está volta (despausar
   * também chega sem publicar). Categoria despausada só reaparece publicando (os produtos
   * dela não estão no retrato).
   */
  private async disponibilidadeAoVivo(): Promise<DisponibilidadeAoVivo> {
    const cardapioId = await this.cardapios.ativoId();
    const [produtos, categorias, opcoes] = await Promise.all([
      this.prisma.produto.findMany({
        where: { cardapioId, disponivel: false },
        select: { id: true },
      }),
      this.prisma.categoria.findMany({
        where: { cardapioId, pausada: true },
        select: { id: true },
      }),
      this.prisma.complementoOpcao.findMany({
        where: { disponivel: false },
        select: { id: true },
      }),
    ]);
    return {
      produtosIndisponiveis: produtos.map((p) => p.id),
      categoriasPausadas: categorias.map((c) => c.id),
      opcoesIndisponiveis: opcoes.map((o) => o.id),
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
    avisos: PublicarAvisos;
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

    // Loja integrada ao Regem (a venda vai para lá pelo código PDV): o que não tem código
    // não tem como ser vendido — o produto seria recusado DEPOIS do pagamento, e a opção
    // paga derrubaria a venda inteira ("a soma dos pagamentos não bate"). Fica fora da
    // versão, e o painel mostra o que ficou (ERR-010/011). Sem integração, nada muda.
    const integrado = await this.regem.resolve().then(
      () => true,
      () => false,
    );
    const produtosSemCodigo: PublicarAvisos['produtosSemCodigo'] = [];
    const opcoesPagas = new Map<string, string>();
    const produtosAtivos = produtos.filter((p) => {
      if (p.categoriaId && pausadaIds.has(p.categoriaId)) return false;
      if (integrado && !codigoPdvRegem(p.externalRefs)) {
        produtosSemCodigo.push({ id: p.id, nome: p.nome });
        return false;
      }
      return true;
    });
    const opcaoEntra = (o: {
      id: string;
      nome: string;
      precoCentavosDelta: number;
      externalRefs: Prisma.JsonValue;
    }): boolean => {
      if (!integrado || o.precoCentavosDelta <= 0) return true;
      if (codigoPdvRegem(o.externalRefs)) return true;
      opcoesPagas.set(o.id, o.nome);
      return false;
    };

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
        grupos: p.complementos.map((pc) => {
          const opcoes = pc.grupo.opcoes.filter(opcaoEntra);
          return {
            id: pc.grupo.id,
            nome: pc.grupo.nome,
            min: pc.grupo.min,
            // `max` nulo = SEM LIMITE. O totem espera um número e lia o nulo como 1 — o
            // grupo "escolha quantos quiser" virava escolha única (ERR-025). O teto é o
            // número de opções, como o Regem já faz no servidor da loja.
            max: pc.grupo.max ?? Math.max(opcoes.length, 1),
            obrigatorio: pc.grupo.obrigatorio,
            ordem: pc.ordem,
            opcoes: opcoes.map((o) => ({
              id: o.id,
              nome: o.nome,
              precoCentavosDelta: o.precoCentavosDelta,
              disponivel: o.disponivel,
              imagemUrl: o.imagemUrl,
              ordem: o.ordem,
              externalRefs: o.externalRefs,
            })),
          };
        }),
      })),
    };

    // Totais do que FOI publicado (não do rascunho).
    const grupos = snapshot.produtos.reduce((n, p) => n + p.grupos.length, 0);
    const opcoes = snapshot.produtos.reduce(
      (n, p) => n + p.grupos.reduce((m, g) => m + g.opcoes.length, 0),
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
      avisos: {
        produtosSemCodigo,
        opcoesPagasSemCodigo: [...opcoesPagas].map(([id, nome]) => ({
          id,
          nome,
        })),
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
      /** Sempre um número: "sem limite" sai como o total de opções. */
      max: number;
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
