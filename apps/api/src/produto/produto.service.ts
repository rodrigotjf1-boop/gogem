import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type Produto } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CardapioService } from '../cardapio/cardapio.service';
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
