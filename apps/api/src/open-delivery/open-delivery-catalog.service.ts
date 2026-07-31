import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { CatalogoPublicacaoService } from '../catalogo/catalogo-publicacao.service';

/**
 * Catálogo no formato Open Delivery (GoGeM provedor). Mapeia o catálogo PUBLICADO
 * (o mesmo que o totem consome) para `Merchant → Category → Item → OptionGroup →
 * Option`, de-para por `externalCode` (= codigo_pdv), dinheiro em REAIS decimais
 * (converte de centavos na borda). Ver packages/contracts/open-delivery.
 */
@Injectable()
export class OpenDeliveryCatalogService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly publicacao: CatalogoPublicacaoService,
  ) {}

  /** Garante que o merchant pedido é o tenant do token (senão 403). */
  private tenantOuFalha(merchantId: string): string {
    const tenantId = TenantContext.getTenantId();
    if (!tenantId || merchantId !== tenantId) {
      throw new ForbiddenException('merchantId não corresponde ao seu app.');
    }
    return tenantId;
  }

  /** Dados do merchant (loja). */
  async merchant(merchantId: string) {
    const tenantId = this.tenantOuFalha(merchantId);
    const empresa = await this.prisma.tenant.findFirst({
      where: { id: tenantId },
      select: { id: true, nome: true },
    });
    return { id: tenantId, name: empresa?.nome ?? 'Loja' };
  }

  /** Catálogo completo do merchant no formato Open Delivery. */
  async catalog(merchantId: string) {
    this.tenantOuFalha(merchantId); // valida o merchant do token
    const publicado = await this.publicacao.getPublicado();
    const merchant = await this.merchant(merchantId);

    if (!('snapshot' in publicado)) {
      // Catálogo publicado sem mudanças (atualizado:false não traz snapshot).
      // Aqui sempre pedimos o corpo cheio (sem `desde`), então isto não ocorre;
      // mas mantemos o fallback defensivo.
      return { merchant, categories: [], items: [] };
    }
    const snap = publicado.snapshot as unknown as CatalogoSnapshot;

    const categories = snap.categorias.map((c) => ({
      id: c.id,
      name: c.nome,
      index: c.ordem,
    }));

    const items = snap.produtos.map((p) => ({
      id: p.id,
      name: p.nome,
      description: p.descricao ?? undefined,
      externalCode: codigoPdv(p.externalRefs),
      categoryId: p.categoriaId ?? '',
      price: reais(p.precoCentavos),
      status: p.disponivel ? 'AVAILABLE' : 'UNAVAILABLE',
      imageUrl: p.imagemUrl ?? undefined,
      badge: p.selo ?? undefined,
      optionGroups: (p.grupos ?? []).map((g) => ({
        id: g.id,
        name: g.nome,
        min: g.min,
        max: g.max,
        index: g.ordem,
        options: (g.opcoes ?? []).map((o) => ({
          id: o.id,
          name: o.nome,
          externalCode: codigoPdv(o.externalRefs),
          price: reais(o.precoCentavosDelta),
          status: o.disponivel ? 'AVAILABLE' : 'UNAVAILABLE',
          index: o.ordem,
        })),
      })),
    }));

    return { merchant, categories, items };
  }
}

/** Centavos → ODMoney (reais decimais). */
function reais(centavos: number): { value: number; currency: 'BRL' } {
  return { value: Math.round(centavos) / 100, currency: 'BRL' };
}

/** Extrai o codigo_pdv do de-para (Json). Ausente = sem externalCode. */
function codigoPdv(externalRefs: unknown): string | undefined {
  if (!Array.isArray(externalRefs)) return undefined;
  for (const r of externalRefs) {
    if (r && typeof r === 'object') {
      const cod = (r as Record<string, unknown>).codigo_pdv;
      if (typeof cod === 'string' && cod.trim()) return cod.trim();
    }
  }
  return undefined;
}

// Shape mínimo do snapshot consumido (espelha catalogo-publicacao).
interface CatalogoSnapshot {
  categorias: Array<{ id: string; nome: string; ordem: number }>;
  produtos: Array<{
    id: string;
    nome: string;
    descricao: string | null;
    precoCentavos: number;
    disponivel: boolean;
    imagemUrl: string | null;
    selo: string | null;
    categoriaId: string | null;
    externalRefs: unknown;
    grupos: Array<{
      id: string;
      nome: string;
      min: number;
      max: number | null;
      ordem: number;
      opcoes: Array<{
        id: string;
        nome: string;
        precoCentavosDelta: number;
        disponivel: boolean;
        ordem: number;
        externalRefs: unknown;
      }>;
    }>;
  }>;
}
