import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type Categoria } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CardapioService } from '../cardapio/cardapio.service';
import { CreateCategoriaDto } from './dto/create-categoria.dto';
import { UpdateCategoriaDto } from './dto/update-categoria.dto';

/**
 * CategoriaService — CRUD de categorias do catálogo.
 *
 * Multi-tenant (CLAUDE.md §2): NENHUM método adiciona `tenantId` à mão. O
 * middleware `tenantScopeMiddleware` do PrismaService injeta o tenant do
 * contexto em toda leitura/escrita e falha fechado sem contexto. Estas rotas
 * ficam atrás do JwtAuthGuard, então o contexto sempre existe.
 */
@Injectable()
export class CategoriaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cardapios: CardapioService,
  ) {}

  /**
   * Lista as categorias do cardápio-alvo (informado ou ativo), ordenadas por
   * `ordem` e depois `nome`.
   */
  async list(cardapioId?: string): Promise<Categoria[]> {
    const alvo = await this.cardapios.resolverAlvo(cardapioId);
    return this.prisma.categoria.findMany({
      where: { cardapioId: alvo },
      orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
    });
  }

  /** Busca uma categoria por id (404 se não existir neste tenant). */
  async getOne(id: string): Promise<Categoria> {
    const categoria = await this.prisma.categoria.findFirst({ where: { id } });
    if (!categoria) {
      throw new NotFoundException('Categoria não encontrada.');
    }
    return categoria;
  }

  /** Cria uma categoria no cardápio-alvo (informado ou ativo). */
  async create(dto: CreateCategoriaDto): Promise<Categoria> {
    // `tenantId` é injetado pelo middleware (§2); os tipos do Prisma o exigem
    // estaticamente, então validamos os campos com `satisfies` e omitimos o
    // tenant do payload.
    const cardapioId = await this.cardapios.resolverAlvo(dto.cardapioId);
    const data = {
      nome: dto.nome,
      ordem: dto.ordem ?? 0,
      cardapioId,
      imagemUrl: dto.imagemUrl ?? null,
      emoji: dto.emoji ?? null,
      cor: dto.cor ?? null,
      pausada: dto.pausada ?? false,
    } satisfies Omit<Prisma.CategoriaUncheckedCreateInput, 'tenantId'>;
    return this.prisma.categoria.create({
      data: data as Prisma.CategoriaUncheckedCreateInput,
    });
  }

  /** Atualização parcial (404 se não existir). */
  async update(id: string, dto: UpdateCategoriaDto): Promise<Categoria> {
    await this.getOne(id); // garante existência + escopo de tenant.
    return this.prisma.categoria.update({
      where: { id },
      data: {
        nome: dto.nome,
        ordem: dto.ordem,
        imagemUrl: dto.imagemUrl,
        emoji: dto.emoji,
        cor: dto.cor,
        pausada: dto.pausada,
      },
    });
  }

  /**
   * Exclui uma categoria. Bloqueia com 409 se houver produtos vinculados
   * (opção mais segura que orfanar produtos — ver deliverables).
   */
  async remove(id: string): Promise<{ id: string }> {
    await this.getOne(id);
    const produtos = await this.prisma.produto.count({
      where: { categoriaId: id },
    });
    if (produtos > 0) {
      throw new ConflictException(
        `Categoria possui ${produtos} produto(s) vinculado(s); remova ou realoque antes de excluir.`,
      );
    }
    await this.prisma.categoria.delete({ where: { id } });
    return { id };
  }
}
