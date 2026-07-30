import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** Linha do relatório de pedidos. */
export interface PedidoRelatorio {
  id: string;
  criadoEm: Date;
  dispositivo: string | null;
  cliente: string | null;
  cpf: string | null;
  consumo: string;
  senha: number | null;
  status: string;
  totalCentavos: number;
  formas: string[];
  itens: number;
  canceladoMotivo: string | null;
}

/** Card de faturamento de um período. */
export interface FaturamentoCard {
  totalCentavos: number;
  pedidos: number;
  ticketMedioCentavos: number;
}

/** Item do ranking de produtos. */
export interface ProdutoRanking {
  codigoPdv: string;
  nome: string;
  quantidade: number;
  pedidos: number;
}

/**
 * RelatorioService — relatórios operacionais (Fase 7). Agrega em memória a
 * partir de leituras tenant-scoped (volume típico de totem por período é baixo).
 * Faturamento conta apenas pedidos `enviado` (concretizados); cancelados/falha
 * ficam fora do faturamento. Dinheiro em centavos.
 */
@Injectable()
export class RelatorioService {
  constructor(private readonly prisma: PrismaService) {}

  /** Pedidos do período (opcionalmente por status), mais novos primeiro. */
  async pedidos(
    de: Date,
    ate: Date,
    status?: string,
  ): Promise<PedidoRelatorio[]> {
    const pedidos = await this.prisma.pedido.findMany({
      where: {
        createdAt: { gte: de, lte: ate },
        ...(status ? { status } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
    const nomes = await this.nomesDispositivos(
      pedidos.map((p) => p.dispositivoId),
    );
    return pedidos.map((p) => ({
      id: p.id,
      criadoEm: p.createdAt,
      dispositivo: p.dispositivoId
        ? (nomes.get(p.dispositivoId) ?? null)
        : null,
      cliente: p.cliente,
      cpf: p.cpf,
      consumo: p.consumo,
      senha: p.senhaLocal,
      status: p.status,
      totalCentavos: p.totalCentavos,
      formas: formasDe(p.pagamentos),
      itens: Array.isArray(p.itens) ? p.itens.length : 0,
      canceladoMotivo: p.canceladoMotivo,
    }));
  }

  /** Cards de faturamento: hoje, 7 dias, mês atual e mês anterior. */
  async resumo(agora: Date): Promise<{
    hoje: FaturamentoCard;
    semana: FaturamentoCard;
    mesAtual: FaturamentoCard;
    mesAnterior: FaturamentoCard;
  }> {
    const inicioHoje = new Date(
      agora.getFullYear(),
      agora.getMonth(),
      agora.getDate(),
    );
    const inicioSemana = new Date(inicioHoje);
    inicioSemana.setDate(inicioSemana.getDate() - 6);
    const inicioMes = new Date(agora.getFullYear(), agora.getMonth(), 1);
    const inicioMesAnterior = new Date(
      agora.getFullYear(),
      agora.getMonth() - 1,
      1,
    );
    const fimMesAnterior = new Date(inicioMes.getTime() - 1);

    return {
      hoje: await this.faturamento(inicioHoje, agora),
      semana: await this.faturamento(inicioSemana, agora),
      mesAtual: await this.faturamento(inicioMes, agora),
      mesAnterior: await this.faturamento(inicioMesAnterior, fimMesAnterior),
    };
  }

  /** Faturamento (só pedidos `enviado`) num intervalo. */
  async faturamento(de: Date, ate: Date): Promise<FaturamentoCard> {
    const agg = await this.prisma.pedido.aggregate({
      where: { status: 'enviado', createdAt: { gte: de, lte: ate } },
      _sum: { totalCentavos: true },
      _count: true,
    });
    const total = agg._sum.totalCentavos ?? 0;
    const pedidos = agg._count;
    return {
      totalCentavos: total,
      pedidos,
      ticketMedioCentavos: pedidos > 0 ? Math.round(total / pedidos) : 0,
    };
  }

  /** Ranking de produtos por quantidade vendida (pedidos `enviado`). */
  async porProduto(de: Date, ate: Date): Promise<ProdutoRanking[]> {
    const pedidos = await this.prisma.pedido.findMany({
      where: { status: 'enviado', createdAt: { gte: de, lte: ate } },
      select: { itens: true },
    });
    const acc = new Map<string, { quantidade: number; pedidos: number }>();
    for (const p of pedidos) {
      if (!Array.isArray(p.itens)) continue;
      const vistos = new Set<string>();
      for (const raw of p.itens) {
        if (!raw || typeof raw !== 'object') continue;
        const it = raw as Record<string, unknown>;
        const cod = (it.codigoPdv ?? '').toString().trim();
        if (!cod) continue;
        const qtd = Number(it.quantidade) || 0;
        const cur = acc.get(cod) ?? { quantidade: 0, pedidos: 0 };
        cur.quantidade += qtd;
        if (!vistos.has(cod)) {
          cur.pedidos += 1;
          vistos.add(cod);
        }
        acc.set(cod, cur);
      }
    }
    const nomes = await this.nomesProdutos([...acc.keys()]);
    return [...acc.entries()]
      .map(([codigoPdv, v]) => ({
        codigoPdv,
        nome: nomes.get(codigoPdv) ?? codigoPdv,
        quantidade: v.quantidade,
        pedidos: v.pedidos,
      }))
      .sort((a, b) => b.quantidade - a.quantidade);
  }

  /** Cancela um pedido (local). Propagação ao Regem = follow-up cross-repo. */
  async cancelar(
    id: string,
    motivo: string,
    agora: Date,
  ): Promise<{ id: string }> {
    const pedido = await this.prisma.pedido.findFirst({ where: { id } });
    if (!pedido) throw new NotFoundException('Pedido não encontrado.');
    if (pedido.status === 'cancelado') {
      throw new BadRequestException('Pedido já está cancelado.');
    }
    await this.prisma.pedido.update({
      where: { id },
      data: {
        status: 'cancelado',
        canceladoEm: agora,
        canceladoMotivo: motivo,
      },
    });
    return { id };
  }

  // ── internos ──────────────────────────────────────────────────────────────

  private async nomesDispositivos(
    ids: (string | null)[],
  ): Promise<Map<string, string>> {
    const unicos = [...new Set(ids.filter((x): x is string => !!x))];
    if (!unicos.length) return new Map();
    const disp = await this.prisma.dispositivo.findMany({
      where: { id: { in: unicos } },
      select: { id: true, nome: true },
    });
    return new Map(disp.map((d) => [d.id, d.nome]));
  }

  /** Mapa codigo_pdv (de-para regem) → nome do produto. */
  private async nomesProdutos(codigos: string[]): Promise<Map<string, string>> {
    if (!codigos.length) return new Map();
    const produtos = await this.prisma.produto.findMany({
      select: { nome: true, externalRefs: true },
    });
    const alvo = new Set(codigos);
    const map = new Map<string, string>();
    for (const p of produtos) {
      const refs = Array.isArray(p.externalRefs) ? p.externalRefs : [];
      for (const r of refs) {
        if (r && typeof r === 'object' && !Array.isArray(r)) {
          const ref = r as Record<string, unknown>;
          const cod = (ref.codigo_pdv ?? '').toString();
          if (ref.sistema === 'regem' && alvo.has(cod)) map.set(cod, p.nome);
        }
      }
    }
    return map;
  }
}

/** Extrai as formas de pagamento (rótulos) do Json de pagamentos. */
function formasDe(pagamentos: unknown): string[] {
  if (!Array.isArray(pagamentos)) return [];
  const out: string[] = [];
  for (const raw of pagamentos) {
    if (raw && typeof raw === 'object') {
      const f = (raw as Record<string, unknown>).forma;
      if (typeof f === 'string' && f) out.push(f);
    }
  }
  return out;
}
