import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  CancelamentoService,
  CancelamentoResultado,
} from '../pagamentos/cancelamento.service';

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

/** Vendas agrupadas por forma de pagamento (com bandeira quando houver). */
export interface PagamentoRanking {
  forma: string;
  bandeira: string | null;
  pedidos: number;
  totalCentavos: number;
}

/** Vendas por hora do dia (0–23, fuso America/Sao_Paulo). */
export interface HorarioPonto {
  hora: number;
  pedidos: number;
  totalCentavos: number;
}

/**
 * RelatorioService — relatórios operacionais (Fase 7). Agrega em memória a
 * partir de leituras tenant-scoped (volume típico de totem por período é baixo).
 * Faturamento conta apenas pedidos `enviado` (concretizados); cancelados/falha
 * ficam fora do faturamento. Dinheiro em centavos.
 */
@Injectable()
export class RelatorioService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cancelamento: CancelamentoService,
  ) {}

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

  /**
   * Vendas por forma de pagamento (pedidos `enviado`). Agrupa por forma +
   * bandeira (ex.: "credito · visa", "pix"). Valor por pagamento vem de
   * `pagamentos[].valor`; sem ele, rateia o total do pedido entre as formas.
   */
  async porPagamento(de: Date, ate: Date): Promise<PagamentoRanking[]> {
    const pedidos = await this.prisma.pedido.findMany({
      where: { status: 'enviado', createdAt: { gte: de, lte: ate } },
      select: { pagamentos: true, totalCentavos: true },
    });
    const acc = new Map<string, PagamentoRanking>();
    for (const p of pedidos) {
      if (!Array.isArray(p.pagamentos) || p.pagamentos.length === 0) continue;
      const n = p.pagamentos.length;
      const vistos = new Set<string>();
      for (const raw of p.pagamentos) {
        if (!raw || typeof raw !== 'object') continue;
        const pg = raw as Record<string, unknown>;
        const forma = (pg.forma ?? '').toString().trim() || 'outro';
        const bandeira =
          typeof pg.bandeira === 'string' && pg.bandeira ? pg.bandeira : null;
        const valor = Number(pg.valor) || Math.round(p.totalCentavos / n);
        const key = `${forma}·${bandeira ?? ''}`;
        const cur = acc.get(key) ?? {
          forma,
          bandeira,
          pedidos: 0,
          totalCentavos: 0,
        };
        cur.totalCentavos += valor;
        if (!vistos.has(key)) {
          cur.pedidos += 1;
          vistos.add(key);
        }
        acc.set(key, cur);
      }
    }
    return [...acc.values()].sort((a, b) => b.totalCentavos - a.totalCentavos);
  }

  /**
   * Vendas por hora do dia (pedidos `enviado`), no fuso America/Sao_Paulo
   * (o createdAt é UTC). Sempre devolve as 24 horas (com zeros) — bom p/ gráfico.
   */
  async porHorario(de: Date, ate: Date): Promise<HorarioPonto[]> {
    const pedidos = await this.prisma.pedido.findMany({
      where: { status: 'enviado', createdAt: { gte: de, lte: ate } },
      select: { createdAt: true, totalCentavos: true },
    });
    const fmtHora = new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/Sao_Paulo',
      hour: '2-digit',
      hourCycle: 'h23',
    });
    const horas: HorarioPonto[] = Array.from({ length: 24 }, (_, h) => ({
      hora: h,
      pedidos: 0,
      totalCentavos: 0,
    }));
    for (const p of pedidos) {
      const h = Number(fmtHora.format(p.createdAt)) % 24;
      horas[h].pedidos += 1;
      horas[h].totalCentavos += p.totalCentavos;
    }
    return horas;
  }

  /**
   * Cancela um pedido pelo admin (relatórios) COM estorno eletrônico (cartão/PIX)
   * quando houver. Delega ao CancelamentoService (fonte única, mesma lógica do
   * cancelamento vindo do Regem). Devolve os detalhes do estorno para a UI.
   */
  async cancelar(id: string, motivo: string): Promise<CancelamentoResultado> {
    return this.cancelamento.cancelarPorId(id, motivo, 'admin');
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

/**
 * Extrai as formas de pagamento (rótulos) do Json de pagamentos. Quando há
 * bandeira (payment_method_id do MP Point), mostra "forma · bandeira" — ex.:
 * "credito · visa", "voucher · alelo".
 */
function formasDe(pagamentos: unknown): string[] {
  if (!Array.isArray(pagamentos)) return [];
  const out: string[] = [];
  for (const raw of pagamentos) {
    if (raw && typeof raw === 'object') {
      const obj = raw as Record<string, unknown>;
      const f = obj.forma;
      if (typeof f === 'string' && f) {
        const band = typeof obj.bandeira === 'string' ? obj.bandeira : '';
        out.push(band ? `${f} · ${band}` : f);
      }
    }
  }
  return out;
}
