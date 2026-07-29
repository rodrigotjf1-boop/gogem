import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCardapioDto } from './dto/create-cardapio.dto';
import { UpdateCardapioDto } from './dto/update-cardapio.dto';

/** Máximo de cardápios por tenant (Fase 3B). */
export const MAX_CARDAPIOS = 2;

/** Cardápio como o admin o vê (com contagem de produtos). */
export interface CardapioView {
  id: string;
  nome: string;
  ativo: boolean;
  ordem: number;
  produtos: number;
}

/**
 * CardapioService — cardápios do tenant (Fase 3B). Regras: até 2 por tenant;
 * exatamente 1 ativo; ativar é exclusivo; não excluir o ativo nem o último. O
 * totem recebe SEMPRE o ativo (a publicação snapshota o ativo).
 *
 * Multi-tenant (§2): o middleware injeta o tenant; nenhum método passa tenantId
 * à mão (exceto o cast de create, padrão da casa).
 */
@Injectable()
export class CardapioService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Garante que o tenant tenha ao menos 1 cardápio ativo e devolve o id do
   * ativo. Auto-cria "Cardápio padrão" para tenants sem nenhum (novos ou legado
   * sem backfill); se houver cardápios mas nenhum ativo, ativa o primeiro.
   */
  async ativoId(): Promise<string> {
    const ativo = await this.prisma.cardapio.findFirst({
      where: { ativo: true },
    });
    if (ativo) return ativo.id;

    const algum = await this.prisma.cardapio.findFirst({
      orderBy: { ordem: 'asc' },
    });
    if (algum) {
      await this.prisma.cardapio.update({
        where: { id: algum.id },
        data: { ativo: true },
      });
      return algum.id;
    }

    const data = {
      nome: 'Cardápio padrão',
      ativo: true,
      ordem: 0,
    } satisfies Omit<Prisma.CardapioUncheckedCreateInput, 'tenantId'>;
    const criado = await this.prisma.cardapio.create({
      data: data as Prisma.CardapioUncheckedCreateInput,
    });
    return criado.id;
  }

  /**
   * Resolve o cardápio-alvo de uma operação de catálogo: o informado (validado
   * no tenant) ou o ativo. Usado por categoria/produto/import.
   */
  async resolverAlvo(cardapioId?: string): Promise<string> {
    if (cardapioId) {
      const existe = await this.prisma.cardapio.findFirst({
        where: { id: cardapioId },
      });
      if (!existe) throw new NotFoundException('Cardápio não encontrado.');
      return existe.id;
    }
    return this.ativoId();
  }

  /** Lista os cardápios do tenant (garante o padrão), com contagem de produtos. */
  async list(): Promise<CardapioView[]> {
    await this.ativoId(); // garante ≥1 ativo
    const rows = await this.prisma.cardapio.findMany({
      orderBy: [{ ativo: 'desc' }, { ordem: 'asc' }, { createdAt: 'asc' }],
      include: { _count: { select: { produtos: true } } },
    });
    return rows.map((c) => ({
      id: c.id,
      nome: c.nome,
      ativo: c.ativo,
      ordem: c.ordem,
      produtos: c._count.produtos,
    }));
  }

  /** Cria um cardápio (inativo). Máx 2. `modo=duplicar` copia o ativo. */
  async create(dto: CreateCardapioDto): Promise<CardapioView> {
    const total = await this.prisma.cardapio.count();
    if (total >= MAX_CARDAPIOS) {
      throw new BadRequestException(
        `Limite de ${MAX_CARDAPIOS} cardápios por loja atingido. Exclua um para criar outro.`,
      );
    }

    const criado = await this.prisma.cardapio.create({
      data: {
        nome: dto.nome,
        ativo: false,
        ordem: total,
      } as Prisma.CardapioUncheckedCreateInput,
    });

    if (dto.modo === 'duplicar') {
      const origem = await this.ativoId();
      await this.duplicarConteudo(origem, criado.id);
    }

    return this.getView(criado.id);
  }

  /** Renomeia um cardápio. */
  async rename(id: string, dto: UpdateCardapioDto): Promise<CardapioView> {
    await this.assertExiste(id);
    await this.prisma.cardapio.update({
      where: { id },
      data: { nome: dto.nome },
    });
    return this.getView(id);
  }

  /** Ativa um cardápio (exclusivo: desativa os demais do tenant). */
  async ativar(id: string): Promise<CardapioView> {
    await this.assertExiste(id);
    await this.prisma.cardapio.updateMany({
      where: { ativo: true },
      data: { ativo: false },
    });
    await this.prisma.cardapio.update({ where: { id }, data: { ativo: true } });
    return this.getView(id);
  }

  /** Exclui um cardápio (bloqueia o ativo e o último). */
  async remove(id: string): Promise<{ id: string }> {
    const alvo = await this.assertExiste(id);
    if (alvo.ativo) {
      throw new BadRequestException(
        'Não é possível excluir o cardápio ativo. Ative outro antes.',
      );
    }
    const total = await this.prisma.cardapio.count();
    if (total <= 1) {
      throw new BadRequestException('A loja precisa de ao menos um cardápio.');
    }
    // Apaga o conteúdo do cardápio (opções → grupos → produtos → categorias).
    await this.apagarConteudo(id);
    await this.prisma.cardapio.delete({ where: { id } });
    return { id };
  }

  // ── internos ────────────────────────────────────────────────────────────

  private async assertExiste(id: string) {
    const c = await this.prisma.cardapio.findFirst({ where: { id } });
    if (!c) throw new NotFoundException('Cardápio não encontrado.');
    return c;
  }

  private async getView(id: string): Promise<CardapioView> {
    const c = await this.prisma.cardapio.findFirst({
      where: { id },
      include: { _count: { select: { produtos: true } } },
    });
    if (!c) throw new NotFoundException('Cardápio não encontrado.');
    return {
      id: c.id,
      nome: c.nome,
      ativo: c.ativo,
      ordem: c.ordem,
      produtos: c._count.produtos,
    };
  }

  /** Cópia profunda: categorias → produtos → grupos → opções de origem→destino. */
  private async duplicarConteudo(origemId: string, destinoId: string) {
    const categorias = await this.prisma.categoria.findMany({
      where: { cardapioId: origemId },
    });
    const mapaCat = new Map<string, string>();
    for (const c of categorias) {
      const nova = await this.prisma.categoria.create({
        data: {
          cardapioId: destinoId,
          nome: c.nome,
          ordem: c.ordem,
        } as Prisma.CategoriaUncheckedCreateInput,
      });
      mapaCat.set(c.id, nova.id);
    }

    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId: origemId },
      include: { grupos: { include: { opcoes: true } } },
    });
    for (const p of produtos) {
      const novo = await this.prisma.produto.create({
        data: {
          cardapioId: destinoId,
          categoriaId: p.categoriaId ? mapaCat.get(p.categoriaId) : null,
          nome: p.nome,
          descricao: p.descricao,
          precoCentavos: p.precoCentavos,
          disponivel: p.disponivel,
          imagemUrl: p.imagemUrl,
          externalRefs: p.externalRefs as Prisma.InputJsonValue,
        } as Prisma.ProdutoUncheckedCreateInput,
      });
      for (const g of p.grupos) {
        const novoG = await this.prisma.complementoGrupo.create({
          data: {
            produtoId: novo.id,
            nome: g.nome,
            min: g.min,
            max: g.max,
            obrigatorio: g.obrigatorio,
            ordem: g.ordem,
          } as Prisma.ComplementoGrupoUncheckedCreateInput,
        });
        for (const o of g.opcoes) {
          await this.prisma.complementoOpcao.create({
            data: {
              grupoId: novoG.id,
              nome: o.nome,
              precoCentavosDelta: o.precoCentavosDelta,
              disponivel: o.disponivel,
              ordem: o.ordem,
              externalRefs: o.externalRefs as Prisma.InputJsonValue,
            } as Prisma.ComplementoOpcaoUncheckedCreateInput,
          });
        }
      }
    }
  }

  /** Apaga o conteúdo de um cardápio (respeita as FKs: opções→grupos→...). */
  private async apagarConteudo(cardapioId: string) {
    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId },
      include: { grupos: true },
    });
    for (const p of produtos) {
      const grupoIds = p.grupos.map((g) => g.id);
      if (grupoIds.length) {
        await this.prisma.complementoOpcao.deleteMany({
          where: { grupoId: { in: grupoIds } },
        });
        await this.prisma.complementoGrupo.deleteMany({
          where: { produtoId: p.id },
        });
      }
    }
    await this.prisma.produto.deleteMany({ where: { cardapioId } });
    await this.prisma.categoria.deleteMany({ where: { cardapioId } });
  }
}
