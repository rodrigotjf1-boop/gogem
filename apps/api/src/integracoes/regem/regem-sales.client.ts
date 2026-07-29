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
}
