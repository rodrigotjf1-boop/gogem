import { Injectable } from '@nestjs/common';
import { RegemConfigResolver } from './regem-config.resolver';

/**
 * Cliente HTTP de venda do Regem (issue #12.2).
 *
 * Lança a venda de totem no Regem via `POST {REGEM_API_BASE}/vendas/externa-pdv`
 * (endpoint L-VEN-1, PR #226 do Regem), autenticado por `X-Sync-Token`. Base e
 * token vêm do ConfigService (`REGEM_API_BASE`, `REGEM_SYNC_TOKEN`) — NUNCA
 * hardcoded (CLAUDE.md §8). Espelha o `RegemCatalogClient`: `fetch` global
 * (Node 20+) com timeout via AbortController.
 *
 * O endpoint do Regem é idempotente por `idempotencyKey` (replay devolve
 * `{ comandaId, idempotente: true }`), somando-se à idempotência local do GoGeM
 * (unique `(tenantId, idempotencyKey)` em `Pedido`).
 *
 * ⚠️ CONTRATO DE DADOS DO REGEM (conferido no código do Regem):
 *   - `pagamentos[].valor` vai em **REAIS decimais** (ex.: 29.90), NÃO centavos.
 *     O Regem deriva o total de `precoVenda` (reais) e exige `somaPag ≈ total`
 *     (tolerância 0,05). Enviar centavos faz toda venda paga falhar com 400.
 *   - `senhaPlataforma` é **string** (o DTO do Regem valida `@IsString`).
 *   A conversão de centavos→reais e número→string acontece no VendasService,
 *   na borda de saída — o GoGeM permanece internamente em centavos (§ dinheiro).
 */

// ── Shape do corpo enviado ao Regem (contrato de `/vendas/externa-pdv`) ──────

/** Item da venda, casado no Regem por `codigoPdv` (de-para §4). */
export interface RegemVendaItem {
  codigoPdv: string;
  quantidade: number;
  observacao?: string;
}

/** Forma de pagamento (split). `valor` em REAIS decimais (contrato do Regem). */
export interface RegemVendaPagamento {
  forma: string;
  valor: number;
  nsu?: string;
  autorizacao?: string;
  formaPagamentoId?: string;
}

/** Corpo do lançamento de venda externa no Regem. */
export interface RegemVendaExternaBody {
  idempotencyKey: string;
  itens: RegemVendaItem[];
  pagamentos: RegemVendaPagamento[];
  cpf?: string;
  taxaServicoPct?: number;
  plataforma?: string;
  /** Tipo de consumo: 'local' (comer aqui) | 'viagem'. O Regem roteia/embala. */
  consumo?: 'local' | 'viagem';
  /** Nº do pedido no totem — string (o DTO do Regem valida `@IsString`). */
  senhaPlataforma?: string;
}

/**
 * Resposta do Regem. No caminho feliz traz `comandaId`, `senha`, `subtotal` e
 * `total` (e `nfce?` se fiscal ativo). Em replay idempotente, o Regem devolve
 * `{ comandaId, idempotente: true }` — os demais campos podem faltar.
 */
export interface RegemVendaExternaResposta {
  comandaId: string;
  senha?: number;
  subtotal?: number;
  total?: number;
  nfce?: unknown;
  idempotente?: boolean;
}

/**
 * Corpo do reporte de FALHA/cancelamento de pagamento ao Regem
 * (`POST /vendas/externa-pdv/falha`). NÃO é uma venda: o Regem lista o cupom
 * "não passou" + `motivo`, sem caixa e sem estoque. `totalCentavos` em CENTAVOS
 * (é só exibição — diferente da venda, que vai em reais).
 */
export interface RegemVendaFalhaBody {
  idempotencyKey: string;
  itens: RegemVendaItem[];
  formaTentada: string;
  totalCentavos: number;
  senhaPlataforma?: string;
  motivo: string;
}

/**
 * Corpo do pedido em DINHEIRO ao Regem (`POST /delivery/totem-dinheiro`).
 * NÃO é venda fechada: vira uma RETIRADA "Totem GoGeM" a receber, cobrada no
 * balcão (finalização no Regem). Idempotente por `idempotencyKey`. `totalCentavos`
 * é opcional (o Regem recalcula pelo preço do servidor).
 */
export interface RegemTotemDinheiroBody {
  idempotencyKey: string;
  itens: RegemVendaItem[];
  cliente?: string;
  senhaPlataforma?: string;
  totalCentavos?: number;
}

/** Timeout padrão da requisição ao Regem (ms). */
const FETCH_TIMEOUT_MS = 15_000;

@Injectable()
export class RegemSalesClient {
  constructor(private readonly resolver: RegemConfigResolver) {}

  /**
   * Lança a venda de totem no Regem (config resolvida por tenant). Lança erro
   * claro quando a config está ausente ou a resposta não é 2xx (status + corpo).
   */
  async lancarVendaExterna(
    body: RegemVendaExternaBody,
  ): Promise<RegemVendaExternaResposta> {
    const { base, token } = await this.resolver.resolve();

    const url = `${base.replace(/\/$/, '')}/vendas/externa-pdv`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: {
          'X-Sync-Token': token,
          'X-Loja-Token': token,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      throw new Error(`Falha ao lançar venda no Regem (${url}): ${motivo}`);
    } finally {
      clearTimeout(timer);
    }

    if (!res.ok) {
      // Inclui o corpo do erro para diagnóstico (best-effort).
      const corpo = await res.text().catch(() => '');
      throw new Error(
        `Venda no Regem respondeu ${res.status} ${res.statusText} (${url}): ${corpo}`,
      );
    }

    return (await res.json()) as RegemVendaExternaResposta;
  }

  /**
   * Lança um pedido em DINHEIRO no Regem como RETIRADA a receber
   * (`POST /delivery/totem-dinheiro`). Auth = `X-Sync-Token` (igual ao
   * `/delivery/ingest`). Idempotente por `idempotencyKey`. Lança erro em falha —
   * o VendasService decide o tratamento (best-effort para o totem).
   */
  async lancarTotemDinheiro(
    body: RegemTotemDinheiroBody,
  ): Promise<RegemVendaExternaResposta> {
    const { base, token } = await this.resolver.resolve();
    const url = `${base.replace(/\/$/, '')}/delivery/totem-dinheiro`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: {
          'X-Sync-Token': token,
          'X-Loja-Token': token,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      throw new Error(`Falha no pedido dinheiro no Regem (${url}): ${motivo}`);
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) {
      const corpo = await res.text().catch(() => '');
      throw new Error(
        `Pedido dinheiro no Regem respondeu ${res.status} ${res.statusText} (${url}): ${corpo}`,
      );
    }
    // Resposta pode vir vazia/variada — o Regem finaliza no balcão. Parse defensivo.
    return (await res.json().catch(() => ({}))) as RegemVendaExternaResposta;
  }

  /**
   * Reporta ao Regem um pagamento que NÃO passou (cupom "não passou" + motivo).
   * BEST-EFFORT: nunca lança — sem config Regem, 404 (endpoint ainda não criado
   * no Regem) ou erro de rede são silenciosos. Nada de venda/caixa é registrado.
   */
  async relatarFalha(body: RegemVendaFalhaBody): Promise<void> {
    let cfg: { base: string; token: string };
    try {
      cfg = await this.resolver.resolve();
    } catch {
      return; // sem integração Regem → nada a reportar
    }
    const url = `${cfg.base.replace(/\/$/, '')}/vendas/externa-pdv/falha`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      await fetch(url, {
        method: 'POST',
        headers: {
          'X-Sync-Token': cfg.token,
          'X-Loja-Token': cfg.token,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      // best-effort: não checamos res.ok nem lançamos.
    } catch {
      // rede/timeout — silencioso (o cliente já viu o erro na tela do totem).
    } finally {
      clearTimeout(timer);
    }
  }
}
