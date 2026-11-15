import { Logger } from '@nestjs/common';
import { causaDeRede } from '../../common/causa-de-rede';
import { clienteDmsIdDoGogem } from './dms-id.cliente';
import { CABECALHO_INTEGRADOR } from './integrador';
import type {
  CredencialRecusada,
  RegemConfig,
  RegemConfigResolver,
} from './regem-config.resolver';

/**
 * A CHAMADA AO REGEM — um lugar só para a credencial, o prazo e as respostas de erro.
 *
 * Duas credenciais na transição da credencial própria do GoGeM (Hub DMS, fase 3):
 *  • o token de integração da loja (`Authorization: Bearer rgm_it_…`), emitido no Regem em
 *    Distribuição › Tokens de integração › "Para quem": GoGeM. É o contrato PÚBLICO da API de
 *    integração do Regem — o mesmo que um produto de fora do grupo DMS usaria (problem+json,
 *    `Retry-After`, um token por loja com escopos);
 *  • sem ele, o token de sincronização de sempre (`X-Sync-Token` + `X-Integrador: gogem`).
 *
 * Com o token novo, recusa (401 ou 403) NÃO volta para o token antigo: revogar no Regem tem de
 * valer (decisão do dono, 19/10/2026). A recusa fica marcada no último teste da integração — o
 * painel mostra o "reconecte" — e as chamadas seguintes nem vão ao Regem até um token novo ser
 * salvo ou o "Testar conexão" passar. Para o totem a venda é "indisponível agora": ela espera na
 * fila e é reenviada (nada se perde). 429: espera o `Retry-After` antes de chamar de novo.
 *
 * A rede da loja não passa por aqui: o totem que fala com o servidor da loja segue como sempre
 * (o servidor da loja nem aceita o token de integração).
 */

const logger = new Logger('ChamadaAoRegem');

/** O formato do token de integração do Regem: `rgm_it_` + 32 bytes em base64url. */
export const FORMATO_TOKEN_INTEGRACAO = /^rgm_it_[A-Za-z0-9_-]{43}$/;

/** Espera sem `Retry-After` legível (segundos) e o teto que o Regem pode pedir (24 h). */
const ESPERA_PADRAO_S = 60;
const ESPERA_MAXIMA_S = 24 * 60 * 60;

/**
 * Os cabeçalhos da chamada: pela LIGAÇÃO (Hub DMS F6), o token do DMS ID do GoGeM + `DMS-Ligacao`;
 * senão os de sempre (`cabecalhosDoRegem`). Sem o cliente do DMS ID configurado (o "Conectar pelo
 * Regem" desligado neste servidor) ou com o DMS ID fora, a chamada não sai: erro passageiro, a
 * venda espera na fila.
 */
async function cabecalhosDaChamada(
  cfg: RegemConfig,
): Promise<Record<string, string>> {
  if (!cfg.ligacao) return cabecalhosDoRegem(cfg);
  const dmsId = clienteDmsIdDoGogem();
  if (!dmsId) {
    throw new Error(
      'A conexão pelo Regem está guardada, mas este servidor não tem o "Conectar pelo Regem" ' +
        'configurado (o aplicativo do GoGeM no DMS ID). Avise o suporte do GoGeM.',
    );
  }
  let token: string;
  try {
    token = await dmsId.token();
  } catch (err) {
    logger.error(
      `O DMS ID não deu o token para o Regem: ${err instanceof Error ? err.message : String(err)}`,
    );
    throw new Error(
      'O DMS ID não respondeu agora (o token para falar com o Regem). Tentamos de novo em instantes.',
    );
  }
  return { Authorization: `Bearer ${token}`, 'DMS-Ligacao': cfg.ligacao };
}

/** Os cabeçalhos da credencial: o token novo sozinho, ou o caminho de sempre. */
export function cabecalhosDoRegem(
  cfg: Pick<RegemConfig, 'token' | 'tokenIntegracao'>,
): Record<string, string> {
  if (cfg.tokenIntegracao) {
    return { Authorization: `Bearer ${cfg.tokenIntegracao}` };
  }
  return {
    'X-Sync-Token': cfg.token,
    'X-Loja-Token': cfg.token,
    ...CABECALHO_INTEGRADOR,
  };
}

/**
 * O Regem recusou o token de integração da loja (401: inválido, vencido ou revogado; 403: sem a
 * permissão). Não é recusa da VENDA: quem a recebe trata como passageiro (a venda espera).
 */
export class RegemCredencialRecusadaError extends Error {
  constructor(
    readonly status: number,
    readonly detalhe: string,
    via: ViaDaCredencial = 'token',
  ) {
    super(mensagemDaRecusa(status, detalhe, via));
    this.name = 'RegemCredencialRecusadaError';
  }
}

/** Por onde o GoGeM fala com o Regem: o token colado ou a ligação do "Conectar pelo Regem". */
export type ViaDaCredencial = 'token' | 'ligacao';

/** O Regem pediu para esperar (429). Passageiro: a venda volta para a fila do totem. */
export class RegemLimiteError extends Error {
  constructor(readonly esperaSeg: number) {
    super(
      `O Regem pediu para esperar ${esperaSeg} s antes da próxima chamada (limite de chamadas do token).`,
    );
    this.name = 'RegemLimiteError';
  }
}

/** O texto que vai para o painel e para o log, com o que fazer. */
export function mensagemDaRecusa(
  status: number,
  detalhe: string,
  via: ViaDaCredencial = 'token',
): string {
  const o = detalhe ? ` ${detalhe.replace(/\s*\.?\s*$/, '.')}` : '';
  if (via === 'ligacao') {
    const deNovo =
      'Conecte de novo pelo Regem, em Integrações › Regem › "Conectar pelo Regem".';
    return status === 403
      ? `A autorização desta loja no Regem não libera isso.${o} ${deNovo}`
      : `O Regem recusou a conexão desta loja (a autorização foi revogada ou trocada no Regem).${o} ${deNovo}`;
  }
  const comoReconectar =
    'Emita outro token no Regem (Distribuição › Tokens de integração, para o GoGeM) e ' +
    'salve na integração Regem do GoGeM.';
  return status === 403
    ? `O token de integração desta loja não tem permissão para isso no Regem.${o} ${comoReconectar}`
    : `O Regem recusou o token de integração desta loja (inválido, vencido ou revogado).${o} ${comoReconectar}`;
}

/** O que vai no "último teste" da integração quando o Regem recusa o token novo (ou a ligação). */
export function ultimoTesteDaRecusa(
  status: number,
  detalhe: string,
  em: Date = new Date(),
  via: ViaDaCredencial = 'token',
): {
  ok: false;
  detalhe: string;
  em: string;
  credencialRecusada: CredencialRecusada;
} {
  const quando = em.toISOString();
  return {
    ok: false,
    detalhe: mensagemDaRecusa(status, detalhe, via),
    em: quando,
    credencialRecusada: { status, detalhe, em: quando },
  };
}

/**
 * O texto do erro do Regem: o `detail` do problem+json (API de integração), o `message` do Nest
 * (string ou lista) ou o começo do corpo.
 */
export function mensagemDoRegem(corpo: string): string {
  try {
    const b = JSON.parse(corpo) as {
      detail?: unknown;
      message?: unknown;
      title?: unknown;
    };
    if (typeof b?.detail === 'string' && b.detail.trim())
      return b.detail.trim();
    const m = b?.message;
    if (Array.isArray(m)) return m.map(String).join('; ');
    if (typeof m === 'string' && m.trim()) return m.trim();
    if (typeof b?.title === 'string' && b.title.trim()) return b.title.trim();
  } catch {
    /* corpo não é JSON */
  }
  return corpo.trim().slice(0, 300) || 'sem detalhe';
}

/** Os segundos do `Retry-After` (número ou data HTTP), entre 1 s e 24 h. */
export function segundosDoRetryAfter(
  valor: string | null,
  agora: number = Date.now(),
): number {
  const v = (valor ?? '').trim();
  let seg = ESPERA_PADRAO_S;
  if (/^\d+$/.test(v)) seg = Number(v);
  else if (v) {
    const quando = Date.parse(v);
    if (Number.isFinite(quando)) seg = Math.ceil((quando - agora) / 1000);
  }
  return Math.min(Math.max(seg, 1), ESPERA_MAXIMA_S);
}

/**
 * Até quando cada integração tem de esperar (429). Fica na memória do processo, por integração:
 * é o recado do Regem para ESTE cliente, não dado da loja; se o processo reiniciar, a pior
 * consequência é uma chamada a mais, que o Regem responde com outro 429.
 */
const esperas = new Map<string, number>();

function chaveDaEspera(cfg: RegemConfig): string {
  return cfg.integracaoId ?? cfg.base;
}

/** Só para os testes: esquece as esperas guardadas. */
export function esquecerEsperasDoRegem(): void {
  esperas.clear();
}

export interface PedidoAoRegem {
  /** Caminho depois da base, ex.: `/sync/catalogo`. */
  caminho: string;
  metodo: 'GET' | 'POST' | 'PUT' | 'DELETE';
  corpo?: unknown;
  prazoMs: number;
  /** O que é, para a mensagem de erro (ex.: "catálogo"). */
  rotulo: string;
  /** "Testar conexão": chama mesmo com a recusa marcada (é o jeito de reconectar). */
  ignorarRecusa?: boolean;
  /**
   * `false` = 401/403 NÃO marcam a recusa do token: voltam para quem chamou, como resposta.
   * Para rota fora das 5 do totem (o registro dos avisos), onde um 403 quer dizer "esta rota
   * ainda não está liberada", não "o token caiu" — bloquear as vendas por isso seria errado.
   */
  marcarRecusa?: boolean;
}

/**
 * Faz a chamada com a credencial certa e devolve a resposta — o chamador trata os outros
 * status como sempre tratou. Lança:
 *  • `RegemCredencialRecusadaError` — token novo recusado agora (401/403) ou já marcado;
 *  • `RegemLimiteError` — 429 agora, ou uma espera pedida antes ainda correndo;
 *  • `Error` com a causa real da rede (sem URL de query, sem cabeçalho).
 */
export async function chamarRegem(
  resolver: Pick<RegemConfigResolver, 'marcarCredencialRecusada'>,
  cfg: RegemConfig,
  p: PedidoAoRegem,
): Promise<Response> {
  // A ligação do "Conectar pelo Regem" (Hub DMS F6) e o token colado são as duas credenciais
  // "novas": a recusa delas fica marcada e segura as chamadas; o `X-Sync-Token` não tem isso.
  const via: ViaDaCredencial = cfg.ligacao ? 'ligacao' : 'token';
  const comTokenNovo = Boolean(cfg.tokenIntegracao || cfg.ligacao);
  if (comTokenNovo && cfg.credencialRecusada && !p.ignorarRecusa) {
    throw new RegemCredencialRecusadaError(
      cfg.credencialRecusada.status,
      cfg.credencialRecusada.detalhe,
      via,
    );
  }
  const chave = chaveDaEspera(cfg);
  const ate = esperas.get(chave);
  if (ate !== undefined) {
    const falta = Math.ceil((ate - Date.now()) / 1000);
    if (falta > 0) throw new RegemLimiteError(falta);
    esperas.delete(chave);
  }

  const url = `${cfg.base.replace(/\/$/, '')}${p.caminho}`;
  let res: Response;
  // Pela ligação, o 401 pode ser só o token do DMS ID vencido: pede outro e tenta uma vez mais.
  for (let vez = 0; ; vez++) {
    const credencial = await cabecalhosDaChamada(cfg);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), p.prazoMs);
    try {
      res = await fetch(url, {
        method: p.metodo,
        headers: {
          ...credencial,
          ...(p.corpo !== undefined
            ? { 'Content-Type': 'application/json' }
            : {}),
          Accept: 'application/json',
        },
        body: p.corpo !== undefined ? JSON.stringify(p.corpo) : undefined,
        signal: controller.signal,
      });
    } catch (err) {
      const motivo =
        causaDeRede(err) ?? (err instanceof Error ? err.message : String(err));
      throw new Error(
        `Falha ao chamar ${p.rotulo} no Regem (${url}): ${motivo}`,
      );
    } finally {
      clearTimeout(timer);
    }
    if (res.status === 401 && cfg.ligacao && vez === 0) {
      clienteDmsIdDoGogem()?.esquecer();
      continue;
    }
    break;
  }

  if (res.status === 429) {
    const seg = segundosDoRetryAfter(res.headers.get('retry-after'));
    esperas.set(chave, Date.now() + seg * 1000);
    logger.warn(`Regem pediu ${seg} s de espera (${p.rotulo}).`);
    throw new RegemLimiteError(seg);
  }

  if (
    comTokenNovo &&
    p.marcarRecusa !== false &&
    (res.status === 401 || res.status === 403)
  ) {
    const detalhe = mensagemDoRegem(await res.text().catch(() => ''));
    logger.warn(
      `Regem recusou ${via === 'ligacao' ? 'a ligação' : 'o token de integração'} (${res.status}, ${p.rotulo}): ${detalhe}`,
    );
    try {
      await resolver.marcarCredencialRecusada(cfg, res.status, detalhe);
    } catch (err) {
      logger.error(
        `Não foi possível marcar a recusa do token de integração: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
    throw new RegemCredencialRecusadaError(res.status, detalhe, via);
  }

  return res;
}
