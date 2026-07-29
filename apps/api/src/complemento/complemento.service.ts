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

/** Etapa vinculada a um produto (grupo reutilizável + a ordem no produto). */
export interface GrupoView {
  id: string;
  produtoId: string;
  nome: string;
  min: number;
  max: number | null;
  obrigatorio: boolean;
  ordem: number;
  opcoes: ComplementoOpcao[];
}

/** Etapa reutilizável (com opções e nº de produtos que a usam). */
export interface EtapaReutilizavel {
  id: string;
  nome: string;
  min: number;
  max: number | null;
  obrigatorio: boolean;
  usos: number;
  opcoes: ComplementoOpcao[];
}

/**
 * ComplementoService — etapas (complementos) REUTILIZÁVEIS + suas opções.
 *
 * A etapa (`ComplementoGrupo`) é cadastrada uma vez e vinculada a vários
 * produtos por `ProdutoComplemento` (com ordem por produto). Editar a etapa
 * reflete em todos os produtos que a usam.
 *
 * Multi-tenant (CLAUDE.md §2): o middleware injeta o tenant; nada passa tenantId
 * à mão (exceto o cast de create). Delta em centavos; de-para PDV nas opções.
 */
@Injectable()
export class ComplementoService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Etapas de um produto (via vínculo) ────────────────────────────────────

  /** Lista as etapas VINCULADAS a um produto (com opções), na ordem do produto. */
  async listGrupos(produtoId: string): Promise<GrupoView[]> {
    await this.assertProduto(produtoId);
    const links = await this.prisma.produtoComplemento.findMany({
      where: { produtoId },
      orderBy: { ordem: 'asc' },
      include: {
        grupo: {
          include: { opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] } },
        },
      },
    });
    return links.map((l) => this.toView(produtoId, l.grupo, l.ordem));
  }

  /** Cria uma etapa NOVA e já a vincula ao produto. */
  async createGrupo(
    produtoId: string,
    dto: CreateGrupoDto,
  ): Promise<GrupoView> {
    await this.assertProduto(produtoId);
    const min = dto.min ?? 0;
    const max = dto.max ?? null;
    this.assertMinMax(min, max);
    const grupo = await this.prisma.complementoGrupo.create({
      data: {
        nome: dto.nome,
        min,
        max,
        obrigatorio: dto.obrigatorio ?? false,
      } as Prisma.ComplementoGrupoUncheckedCreateInput,
    });
    const ordem = dto.ordem ?? (await this.proximaOrdem(produtoId));
    await this.vincular(produtoId, grupo.id, ordem);
    return this.toView(produtoId, { ...grupo, opcoes: [] }, ordem);
  }

  /** Vincula uma etapa EXISTENTE (reutilizar) a um produto. */
  async anexar(produtoId: string, grupoId: string): Promise<GrupoView> {
    await this.assertProduto(produtoId);
    const grupo = await this.getGrupoComOpcoes(grupoId);
    const jaVinculada = await this.prisma.produtoComplemento.findFirst({
      where: { produtoId, grupoId },
    });
    if (jaVinculada) {
      throw new BadRequestException('Esta etapa já está neste produto.');
    }
    const ordem = await this.proximaOrdem(produtoId);
    await this.vincular(produtoId, grupoId, ordem);
    return this.toView(produtoId, grupo, ordem);
  }

  /** Desvincula uma etapa de um produto (NÃO apaga a etapa reutilizável). */
  async desanexar(
    produtoId: string,
    grupoId: string,
  ): Promise<{ produtoId: string; grupoId: string }> {
    const link = await this.prisma.produtoComplemento.findFirst({
      where: { produtoId, grupoId },
    });
    if (!link)
      throw new NotFoundException('Etapa não vinculada a este produto.');
    await this.prisma.produtoComplemento.delete({ where: { id: link.id } });
    return { produtoId, grupoId };
  }

  /** Reordena uma etapa dentro de um produto. */
  async reordenar(
    produtoId: string,
    grupoId: string,
    ordem: number,
  ): Promise<{ produtoId: string; grupoId: string; ordem: number }> {
    const link = await this.prisma.produtoComplemento.findFirst({
      where: { produtoId, grupoId },
    });
    if (!link)
      throw new NotFoundException('Etapa não vinculada a este produto.');
    await this.prisma.produtoComplemento.update({
      where: { id: link.id },
      data: { ordem },
    });
    return { produtoId, grupoId, ordem };
  }

  // ── Catálogo de etapas reutilizáveis ──────────────────────────────────────

  /** Lista TODAS as etapas reutilizáveis do tenant (com opções e nº de usos). */
  async listReutilizaveis(): Promise<EtapaReutilizavel[]> {
    const grupos = await this.prisma.complementoGrupo.findMany({
      orderBy: { nome: 'asc' },
      include: {
        opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] },
        _count: { select: { produtos: true } },
      },
    });
    return grupos.map((g) => ({
      id: g.id,
      nome: g.nome,
      min: g.min,
      max: g.max,
      obrigatorio: g.obrigatorio,
      usos: g._count.produtos,
      opcoes: g.opcoes,
    }));
  }

  /** Cria uma etapa reutilizável SEM vincular (biblioteca de etapas). */
  async createReutilizavel(dto: CreateGrupoDto): Promise<ComplementoGrupo> {
    const min = dto.min ?? 0;
    const max = dto.max ?? null;
    this.assertMinMax(min, max);
    return this.prisma.complementoGrupo.create({
      data: {
        nome: dto.nome,
        min,
        max,
        obrigatorio: dto.obrigatorio ?? false,
      } as Prisma.ComplementoGrupoUncheckedCreateInput,
    });
  }

  /** Atualiza uma etapa reutilizável (reflete em todos os produtos que a usam). */
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
      },
    });
  }

  /** Exclui a etapa reutilizável: opções + vínculos + a etapa. */
  async removeGrupo(id: string): Promise<{ id: string }> {
    await this.getGrupo(id);
    await this.prisma.complementoOpcao.deleteMany({ where: { grupoId: id } });
    await this.prisma.produtoComplemento.deleteMany({ where: { grupoId: id } });
    await this.prisma.complementoGrupo.delete({ where: { id } });
    return { id };
  }

  async getGrupo(id: string): Promise<ComplementoGrupo> {
    const grupo = await this.prisma.complementoGrupo.findFirst({
      where: { id },
    });
    if (!grupo) throw new NotFoundException('Etapa não encontrada.');
    return grupo;
  }

  // ── Opções ────────────────────────────────────────────────────────────────

  async getOpcao(id: string): Promise<ComplementoOpcao> {
    const opcao = await this.prisma.complementoOpcao.findFirst({
      where: { id },
    });
    if (!opcao)
      throw new NotFoundException('Opção de complemento não encontrada.');
    return opcao;
  }

  /** Cria uma opção sob uma etapa; valida existência da etapa no tenant. */
  async createOpcao(
    grupoId: string,
    dto: CreateOpcaoDto,
  ): Promise<ComplementoOpcao> {
    await this.getGrupo(grupoId);
    const data = {
      grupoId,
      nome: dto.nome,
      precoCentavosDelta: dto.precoCentavosDelta ?? 0,
      disponivel: dto.disponivel ?? true,
      imagemUrl: dto.imagemUrl ?? null,
      ordem: dto.ordem ?? 0,
      externalRefs: normalizeRefs(dto.externalRefs),
    } satisfies Omit<Prisma.ComplementoOpcaoUncheckedCreateInput, 'tenantId'>;
    return this.prisma.complementoOpcao.create({
      data: data as Prisma.ComplementoOpcaoUncheckedCreateInput,
    });
  }

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
        imagemUrl: dto.imagemUrl,
        ordem: dto.ordem,
        externalRefs:
          dto.externalRefs === undefined
            ? undefined
            : normalizeRefs(dto.externalRefs),
      },
    });
  }

  async removeOpcao(id: string): Promise<{ id: string }> {
    await this.getOpcao(id);
    await this.prisma.complementoOpcao.delete({ where: { id } });
    return { id };
  }

  // ── internos ────────────────────────────────────────────────────────────

  private async getGrupoComOpcoes(
    id: string,
  ): Promise<ComplementoGrupo & { opcoes: ComplementoOpcao[] }> {
    const grupo = await this.prisma.complementoGrupo.findFirst({
      where: { id },
      include: { opcoes: { orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] } },
    });
    if (!grupo) throw new NotFoundException('Etapa não encontrada.');
    return grupo;
  }

  private async vincular(produtoId: string, grupoId: string, ordem: number) {
    const data = { produtoId, grupoId, ordem } satisfies Omit<
      Prisma.ProdutoComplementoUncheckedCreateInput,
      'tenantId'
    >;
    await this.prisma.produtoComplemento.create({
      data: data as Prisma.ProdutoComplementoUncheckedCreateInput,
    });
  }

  private async proximaOrdem(produtoId: string): Promise<number> {
    const agg = await this.prisma.produtoComplemento.aggregate({
      where: { produtoId },
      _max: { ordem: true },
    });
    return (agg._max.ordem ?? -1) + 1;
  }

  private toView(
    produtoId: string,
    grupo: ComplementoGrupo & { opcoes: ComplementoOpcao[] },
    ordem: number,
  ): GrupoView {
    return {
      id: grupo.id,
      produtoId,
      nome: grupo.nome,
      min: grupo.min,
      max: grupo.max,
      obrigatorio: grupo.obrigatorio,
      ordem,
      opcoes: grupo.opcoes,
    };
  }

  private async assertProduto(produtoId: string): Promise<void> {
    const produto = await this.prisma.produto.findFirst({
      where: { id: produtoId },
    });
    if (!produto) {
      throw new BadRequestException('produtoId inexistente neste tenant.');
    }
  }

  private assertMinMax(min: number, max: number | null): void {
    if (min < 0) throw new BadRequestException('min deve ser ≥ 0.');
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
