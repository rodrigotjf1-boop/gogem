import { Injectable } from '@nestjs/common';
import { RegemConfigResolver, type RegemConfig } from './regem-config.resolver';
import { chamarRegem } from './chamada-regem';

/**
 * Cliente HTTP do catálogo do Regem (fatia 3).
 *
 * Puxa o catálogo publicado do Regem por `codigo_pdv` (contrato real do
 * endpoint `GET {apiBase}/sync/catalogo`). A credencial (token de integração
 * `Bearer rgm_it_…` ou o `X-Sync-Token` de sempre), o prazo e as respostas de
 * erro moram em `chamada-regem.ts`. Base e tokens são resolvidos POR TENANT pelo
 * `RegemConfigResolver` (loja → empresa; sem Regem padrão).
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
  /** URL pública da foto do produto (Supabase). Pode ser null/ausente. */
  imagem?: string | null;
  /** Preço de venda em reais (string decimal), ex. "29.90". */
  precoVenda: string | null;
  categoriaId: string | null;
  disponivelCardapio: boolean;
  disponivelBalcao: boolean;
  ativo: boolean;
  /** Canais de delivery pausados p/ este produto (ex.: ['ifood','gogem']). */
  canaisPausados?: string[];
  /** Pausado por estoque (esgotado) no Regem. */
  pausadoEstoque?: boolean;
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
  constructor(private readonly resolver: RegemConfigResolver) {}

  /**
   * Busca o catálogo publicado do Regem (config resolvida por tenant). Lança
   * erro claro quando a config está ausente ou a resposta não é 2xx.
   */
  async fetchCatalogo(): Promise<RegemCatalogo> {
    return this.fetchCatalogoWith(await this.resolver.resolve());
  }

  /**
   * Igual a `fetchCatalogo`, mas com config explícita — usado pelo "testar
   * conexão" (que valida credenciais AINDA não ativadas, sem passar pelo
   * resolver, que só considera integrações ativas).
   */
  async fetchCatalogoWith(
    cfg: RegemConfig,
    opts?: { ignorarRecusa?: boolean },
  ): Promise<RegemCatalogo> {
    const res = await chamarRegem(this.resolver, cfg, {
      caminho: '/sync/catalogo',
      metodo: 'GET',
      prazoMs: FETCH_TIMEOUT_MS,
      rotulo: 'o catálogo',
      ignorarRecusa: opts?.ignorarRecusa,
    });

    if (!res.ok) {
      throw new Error(
        `Catálogo do Regem respondeu ${res.status} ${res.statusText} (${res.url || cfg.base}).`,
      );
    }

    return (await res.json()) as RegemCatalogo;
  }
}
