import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  type ComplementoGrupo,
  type ComplementoOpcao,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ExternalRefDto } from '../produto/dto/external-ref.dto';
import { CreateGrupoDto } from './dto/create-grupo.dto';
import { CreateOpcaoDto } from './dto/create-opcao.dto';
import { UpdateGrupoDto } from './dto/update-grupo.dto';
import { UpdateOpcaoDto } from './dto/update-opcao.dto';

/**
 * ComplementoService — grupos de complementos (etapas) + suas opções (fatia 2b).
 *
 * Multi-tenant (CLAUDE.md §2): NENHUM método adiciona `tenantId` à mão; o
 * middleware do Prisma injeta o tenant do contexto e falha fechado sem ele.
 * Preço (delta) sempre em centavos (inteiro). De-para PDV (§4) nas opções.
 */
@Injectable()
export class ComplementoService {
  constructor(private readonly prisma: PrismaService) {}

  /** Lista os grupos de um produto (com suas opções), ordenados. */
  async listGrupos(produtoId: string): Promise<ComplementoGrupo[]> {
    await this.assertProduto(produtoId);
    return this.prisma.complementoGrupo.findMany({
      where: { produtoId },
      orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
      include: {
        opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] },
      },
    });
  }

  /** Busca um grupo por id (404 se não existir neste tenant). */
  async getGrupo(id: string): Promise<ComplementoGrupo> {
    const grupo = await this.prisma.complementoGrupo.findFirst({
      where: { id },
    });
    if (!grupo) {
      throw new NotFoundException('Grupo de complementos não encontrado.');
    }
    return grupo;
  }

  /** Cria um grupo sob um produto; valida existência do produto e min/max. */
  async createGrupo(
    produtoId: string,
    dto: CreateGrupoDto,
  ): Promise<ComplementoGrupo> {
    await this.assertProduto(produtoId);
    const min = dto.min ?? 0;
    const max = dto.max ?? null;
    this.assertMinMax(min, max);
    // `tenantId` é injetado pelo middleware (§2); validamos os campos com
    // `satisfies` e omitimos o tenant do payload.
    const data = {
      produtoId,
      nome: dto.nome,
      min,
      max,
      obrigatorio: dto.obrigatorio ?? false,
      ordem: dto.ordem ?? 0,
    } satisfies Omit<Prisma.ComplementoGrupoUncheckedCreateInput, 'tenantId'>;
    return this.prisma.complementoGrupo.create({
      data: data as Prisma.ComplementoGrupoUncheckedCreateInput,
    });
  }

  /** Atualização parcial de grupo (404 se não existir; revalida min/max). */
  async updateGrupo(
    id: string,
    dto: UpdateGrupoDto,
  ): Promise<ComplementoGrupo> {
    const atual = await this.getGrupo(id);
    const min = dto.min ?? atual.min;
    const max = dto.max !== undefined ? dto.max : atual.max;
    this.assertMinMax(min, max);
    return this.prisma.complementoGrupo.update({
      where: { id },
      data: {
        nome: dto.nome,
        min: dto.min,
        max: dto.max,
        obrigatorio: dto.obrigatorio,
        ordem: dto.ordem,
      },
    });
  }

  /**
   * Remove um grupo e suas opções. Cascade explícito (não há onDelete Cascade
   * no schema): apaga as opções primeiro, depois o grupo — tudo escopado por
   * tenant pelo middleware.
   */
  async removeGrupo(id: string): Promise<{ id: string }> {
    await this.getGrupo(id);
    await this.prisma.complementoOpcao.deleteMany({ where: { grupoId: id } });
    await this.prisma.complementoGrupo.delete({ where: { id } });
    return { id };
  }

  /** Busca uma opção por id (404 se não existir neste tenant). */
  async getOpcao(id: string): Promise<ComplementoOpcao> {
    const opcao = await this.prisma.complementoOpcao.findFirst({
      where: { id },
    });
    if (!opcao) {
      throw new NotFoundException('Opção de complemento não encontrada.');
    }
    return opcao;
  }

  /** Cria uma opção sob um grupo; valida existência do grupo no tenant. */
  async createOpcao(
    grupoId: string,
    dto: CreateOpcaoDto,
  ): Promise<ComplementoOpcao> {
    await this.getGrupo(grupoId); // 404 se o grupo não existir no tenant.
    const data = {
      grupoId,
      nome: dto.nome,
      precoCentavosDelta: dto.precoCentavosDelta ?? 0,
      disponivel: dto.disponivel ?? true,
      ordem: dto.ordem ?? 0,
      externalRefs: normalizeRefs(dto.externalRefs),
    } satisfies Omit<Prisma.ComplementoOpcaoUncheckedCreateInput, 'tenantId'>;
    return this.prisma.complementoOpcao.create({
      data: data as Prisma.ComplementoOpcaoUncheckedCreateInput,
    });
  }

  /** Atualização parcial de opção (404 se não existir). */
  async updateOpcao(
    id: string,
    dto: UpdateOpcaoDto,
  ): Promise<ComplementoOpcao> {
    await this.getOpcao(id);
    return this.prisma.complementoOpcao.update({
      where: { id },
      data: {
        nome: dto.nome,
        precoCentavosDelta: dto.precoCentavosDelta,
        disponivel: dto.disponivel,
        ordem: dto.ordem,
        externalRefs:
          dto.externalRefs === undefined
            ? undefined
            : normalizeRefs(dto.externalRefs),
      },
    });
  }

  /** Remove uma opção (404 se não existir). */
  async removeOpcao(id: string): Promise<{ id: string }> {
    await this.getOpcao(id);
    await this.prisma.complementoOpcao.delete({ where: { id } });
    return { id };
  }

  /** Garante que o produto existe no tenant (senão 400). */
  private async assertProduto(produtoId: string): Promise<void> {
    const produto = await this.prisma.produto.findFirst({
      where: { id: produtoId },
    });
    if (!produto) {
      throw new BadRequestException('produtoId inexistente neste tenant.');
    }
  }

  /** Coerência min/max: min ≥ 0; se `max` != null então `max` ≥ `min`. */
  private assertMinMax(min: number, max: number | null): void {
    if (min < 0) {
      throw new BadRequestException('min deve ser ≥ 0.');
    }
    if (max !== null && max < min) {
      throw new BadRequestException(
        'max deve ser ≥ min (ou nulo = ilimitado).',
      );
    }
  }
}

/**
 * Normaliza os refs para valor JSON puro persistível no Json do Prisma
 * (`undefined` → array vazio; descarta `loja` ausente). Mesmo shape do Produto.
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
