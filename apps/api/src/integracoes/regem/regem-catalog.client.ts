import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Cliente HTTP do catálogo do Regem (fatia 3).
 *
 * Puxa o catálogo publicado do Regem por `codigo_pdv` (contrato real do
 * endpoint `GET {REGEM_API_BASE}/sync/catalogo`, autenticado por
 * `X-Sync-Token`). Base e token vêm do ConfigService (`REGEM_API_BASE`,
 * `REGEM_SYNC_TOKEN`). Usa o `fetch` global (Node 20+) com timeout via
 * AbortController.
 *
 * IMPORTANTE (contrato do Regem): `precoVenda`/`precoDelta` chegam como
 * DECIMAL em reais serializado como string (numeric do Postgres), ex.
 * "29.90". A conversão para centavos inteiros é feita no serviço de import
 * (`reaisToCentavos`), não aqui.
 */

// ── Shape da resposta do Regem (contrato real de `/sync/catalogo`) ──────────

/** Opção de um grupo de complemento no Regem. */
export interface RegemOpcao {
  id: string;
  nome: string;
  /** Delta de preço em reais (string decimal), ex. "5.00". Pode ser null. */
  precoDelta: string | null;
  /** De-para PDV da opção (chave do de-para). Pode ser null. */
  codigoPdv: string | null;
  ordem: number;
}

/** Grupo de complementos (etapa) de um produto no Regem. */
export interface RegemGrupo {
  id: string;
  nome: string;
  tipo?: string;
  min: number;
  max: number | null;
  obrigatorio: boolean;
  ordem: number;
  opcoes: RegemOpcao[];
}

/** Produto do catálogo do Regem. */
export interface RegemProduto {
  id: string;
  /** Código PDV do produto (chave do de-para §4). Pode ser null. */
  codigo: string | null;
  nome: string;
  descricao: string | null;
  /** Preço de venda em reais (string decimal), ex. "29.90". */
  precoVenda: string | null;
  categoriaId: string | null;
  disponivelCardapio: boolean;
  disponivelBalcao: boolean;
  ativo: boolean;
  grupos: RegemGrupo[];
}

/** Categoria do catálogo do Regem. */
export interface RegemCategoria {
  id: string;
  nome: string;
  ordem: number;
}

/** Payload completo de `/sync/catalogo`. */
export interface RegemCatalogo {
  geradoEm: string;
  categorias: RegemCategoria[];
  produtos: RegemProduto[];
}

/** Timeout padrão da requisição ao Regem (ms). */
const FETCH_TIMEOUT_MS = 15_000;

@Injectable()
export class RegemCatalogClient {
  constructor(private readonly config: ConfigService) {}

  /**
   * Busca o catálogo publicado do Regem. Lança erro claro quando a config
   * está ausente ou a resposta não é 2xx (inclui o status).
   */
  async fetchCatalogo(): Promise<RegemCatalogo> {
    const base = this.config.get<string>('REGEM_API_BASE');
    const token = this.config.get<string>('REGEM_SYNC_TOKEN');
    if (!base || !token) {
      throw new Error(
        'Integração Regem não configurada: defina REGEM_API_BASE e REGEM_SYNC_TOKEN.',
      );
    }

    const url = `${base.replace(/\/$/, '')}/sync/catalogo`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'GET',
        headers: {
          'X-Sync-Token': token,
          Accept: 'application/json',
        },
        signal: controller.signal,
      });
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      throw new Error(
        `Falha ao chamar o catálogo do Regem (${url}): ${motivo}`,
      );
    } finally {
      clearTimeout(timer);
    }

    if (!res.ok) {
      throw new Error(
        `Catálogo do Regem respondeu ${res.status} ${res.statusText} (${url}).`,
      );
    }

    return (await res.json()) as RegemCatalogo;
  }
}
