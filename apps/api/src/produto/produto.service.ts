import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type Produto } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CardapioService } from '../cardapio/cardapio.service';
import { RegemPauseClient } from '../integracoes/regem/regem-pause.client';
import { CreateProdutoDto } from './dto/create-produto.dto';
import { ExternalRefDto } from './dto/external-ref.dto';
import { ListProdutosQuery } from './dto/list-produtos.query';
import { UpdateProdutoDto } from './dto/update-produto.dto';

/**
 * ProdutoService — CRUD de produtos do catálogo + de-para PDV (§4).
 *
 * Multi-tenant (CLAUDE.md §2): NENHUM método adiciona `tenantId` à mão; o
 * middleware do Prisma injeta o tenant do contexto e falha fechado sem ele.
 * Preço sempre em centavos (inteiro).
 */
@Injectable()
export class ProdutoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cardapios: CardapioService,
    private readonly regemPause: RegemPauseClient,
  ) {}

  /**
   * Lista produtos do cardápio-alvo (informado ou ativo), com filtros opcionais,
   * ordenados por nome.
   */
  async list(query: ListProdutosQuery): Promise<Produto[]> {
    const cardapioId = await this.cardapios.resolverAlvo(query.cardapioId);
    const where: Prisma.ProdutoWhereInput = { cardapioId };
    if (query.categoriaId !== undefined) where.categoriaId = query.categoriaId;
    if (query.disponivel !== undefined) where.disponivel = query.disponivel;
    return this.prisma.produto.findMany({
      where,
      orderBy: { nome: 'asc' },
    });
  }

  /** Busca um produto por id (404 se não existir neste tenant). */
  async getOne(id: string): Promise<Produto> {
    const produto = await this.prisma.produto.findFirst({ where: { id } });
    if (!produto) {
      throw new NotFoundException('Produto não encontrado.');
    }
    return produto;
  }

  /** Cria um produto no cardápio-alvo; valida `categoriaId` se informado. */
  async create(dto: CreateProdutoDto): Promise<Produto> {
    if (dto.categoriaId) {
      await this.assertCategoria(dto.categoriaId);
    }
    // `tenantId` é injetado pelo middleware (§2); os tipos do Prisma o exigem
    // estaticamente, então validamos os campos com `satisfies` e omitimos o
    // tenant do payload.
    const cardapioId = await this.cardapios.resolverAlvo(dto.cardapioId);
    const data = {
      nome: dto.nome,
      descricao: dto.descricao,
      precoCentavos: dto.precoCentavos,
      disponivel: dto.disponivel ?? true,
      imagemUrl: dto.imagemUrl ?? null,
      selo: dto.selo ?? null,
      categoriaId: dto.categoriaId,
      cardapioId,
      externalRefs: normalizeRefs(dto.externalRefs),
    } satisfies Omit<Prisma.ProdutoUncheckedCreateInput, 'tenantId'>;
    return this.prisma.produto.create({
      data: data as Prisma.ProdutoUncheckedCreateInput,
    });
  }

  /** Atualização parcial (404 se não existir; valida categoria se trocada). */
  async update(id: string, dto: UpdateProdutoDto): Promise<Produto> {
    await this.getOne(id);
    if (dto.categoriaId) {
      await this.assertCategoria(dto.categoriaId);
    }
    return this.prisma.produto.update({
      where: { id },
      data: {
        nome: dto.nome,
        descricao: dto.descricao,
        precoCentavos: dto.precoCentavos,
        disponivel: dto.disponivel,
        imagemUrl: dto.imagemUrl,
        selo: dto.selo,
        categoriaId: dto.categoriaId,
        externalRefs:
          dto.externalRefs === undefined
            ? undefined
            : normalizeRefs(dto.externalRefs),
      },
    });
  }

  /** Remove um produto (404 se não existir). */
  async remove(id: string): Promise<{ id: string }> {
    await this.getOne(id);
    await this.prisma.produto.delete({ where: { id } });
    return { id };
  }

  /** Upsells "Peça também" configurados no produto (com dados do sugerido). */
  async listUpsells(id: string): Promise<
    Array<{
      id: string;
      sugeridoId: string;
      nome: string;
      precoCentavos: number;
      imagemUrl: string | null;
      ordem: number;
    }>
  > {
    await this.getOne(id);
    const rows = await this.prisma.produtoUpsell.findMany({
      where: { produtoId: id },
      orderBy: { ordem: 'asc' },
      include: { sugerido: true },
    });
    return rows.map((r) => ({
      id: r.id,
      sugeridoId: r.sugeridoId,
      nome: r.sugerido.nome,
      precoCentavos: r.sugerido.precoCentavos,
      imagemUrl: r.sugerido.imagemUrl,
      ordem: r.ordem,
    }));
  }

  /**
   * Substitui (replace-all) a lista de upsells do produto, na ordem enviada.
   * Deduplica, ignora o próprio produto e valida que os sugeridos existem no
   * tenant (o `findMany` já é tenant-scoped pelo middleware §2).
   */
  async setUpsells(
    id: string,
    sugeridoIds: string[],
  ): Promise<{ total: number }> {
    await this.getOne(id);
    const ids = [...new Set(sugeridoIds)].filter((s) => s !== id);
    if (ids.length) {
      const encontrados = await this.prisma.produto.findMany({
        where: { id: { in: ids } },
        select: { id: true },
      });
      if (encontrados.length !== ids.length) {
        throw new BadRequestException(
          'Algum produto sugerido não existe neste tenant.',
        );
      }
    }
    await this.prisma.$transaction([
      this.prisma.produtoUpsell.deleteMany({ where: { produtoId: id } }),
      ...ids.map((sugeridoId, ordem) =>
        this.prisma.produtoUpsell.create({
          data: {
            produtoId: id,
            sugeridoId,
            ordem,
          } as Prisma.ProdutoUpsellUncheckedCreateInput,
        }),
      ),
    ]);
    return { total: ids.length };
  }

  /**
   * Pausa/despausa o produto no totem (Fase 4). Aplica a disponibilidade LOCAL
   * (disponivel = !pausado) e, se o produto tem código PDV do Regem, propaga a
   * pausa ao Regem (best-effort: falha remota não desfaz a pausa local).
   */
  async pausar(
    id: string,
    pausado: boolean,
  ): Promise<{ produto: Produto; propagadoRegem: boolean }> {
    const atual = await this.getOne(id);
    const produto = await this.prisma.produto.update({
      where: { id },
      data: { disponivel: !pausado },
    });
    const codigo = codigoPdvRegem(atual.externalRefs);
    const propagadoRegem = codigo
      ? await this.regemPause.pausar(codigo, pausado)
      : false;
    return { produto, propagadoRegem };
  }

  /** Substitui o de-para PDV inteiro do produto (§4). */
  async setExternalRefs(id: string, refs: ExternalRefDto[]): Promise<Produto> {
    await this.getOne(id);
    return this.prisma.produto.update({
      where: { id },
      data: { externalRefs: normalizeRefs(refs) },
    });
  }

  /** Garante que a categoria existe no tenant (senão 400). */
  private async assertCategoria(categoriaId: string): Promise<void> {
    const categoria = await this.prisma.categoria.findFirst({
      where: { id: categoriaId },
    });
    if (!categoria) {
      throw new BadRequestException('categoriaId inexistente neste tenant.');
    }
  }
}

/** Extrai o código PDV do Regem do de-para (Json) do produto, ou null. */
function codigoPdvRegem(externalRefs: Prisma.JsonValue): string | null {
  if (!Array.isArray(externalRefs)) return null;
  for (const r of externalRefs) {
    if (r && typeof r === 'object' && !Array.isArray(r)) {
      const ref = r as Record<string, unknown>;
      if (ref.sistema === 'regem' && typeof ref.codigo_pdv === 'string') {
        return ref.codigo_pdv;
      }
    }
  }
  return null;
}

/**
 * Normaliza os refs para valor JSON puro persistível no Json do Prisma
 * (`undefined` → array vazio; descarta `loja` ausente).
 */
function normalizeRefs(
  refs: ExternalRefDto[] | undefined,
): Prisma.InputJsonValue {
  return (refs ?? []).map((r) => {
    const ref: Record<string, string> = {
      sistema: r.sistema,
      codigo_pdv: r.codigo_pdv,
    };
    if (r.loja !== undefined) ref.loja = r.loja;
    return ref;
  });
}
