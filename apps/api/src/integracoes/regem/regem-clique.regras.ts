import { createHash, randomBytes } from 'node:crypto';

/**
 * "CONECTAR PELO REGEM" — as peças sem rede nem banco (Hub DMS, F6, plano "Clique GoGeM → Regem",
 * 15/11/2026; protótipo `prototipos/clique-gogem.html` do hub).
 *
 * O GoGeM é o APLICATIVO que pede (Padrão DMS §3): empurra o pedido ao Regem com o token do DMS ID
 * (RFC 9126), manda a pessoa à página do Regem com o número e, na volta, troca o código pela
 * LIGAÇÃO de cada loja que o presidente marcou. O contrato é o do Regem
 * (`docs/integracao-gogem/ENDPOINTS.md` de lá, "Pelo clique"): PKCE S256, `state` preso a quem
 * começou e `iss` na volta (RFC 9207). As MESMAS três permissões do totem do token `rgm_it_` de
 * hoje, todas necessárias (decisão G-2).
 */

/** O que o totem faz no Regem: ler o cardápio, pausar no canal dele e lançar a venda. */
export const PERMISSOES_DO_TOTEM = [
  'totem.catalogo.ler',
  'totem.produtos.pausar',
  'totem.vendas.lancar',
] as const;

export const VALIDADE_DO_PEDIDO_MS = 10 * 60_000;

const CAMINHO_DA_PORTA = '/integracao';
const CAMINHO_DA_PAGINA = '/integracoes/autorizar';
const CAMINHO_DA_VOLTA = '/integracoes/regem/volta';

export type ConfigDoClique =
  | {
      ligado: true;
      /** A API do Regem com o `/api/v1` (a mesma base das chamadas do totem). */
      base: string;
      /** A origem da API do Regem: é o `iss` da volta. */
      emissorDoRegem: string;
      /** O recurso do Regem no DMS ID (o destino do token): `<base>/integracao`. */
      recurso: string;
      /** A página do Regem onde o presidente autoriza. */
      pagina: string;
      /** A volta do GoGeM, cadastrada na ficha dele no Regem. */
      volta: string;
      emissorDmsId: string;
      aplicativo: string;
      segredo: string;
    }
  | { ligado: false; motivo: string | null };

/** Endereço https (ou http da própria máquina, em teste), sem usuário, busca nem fragmento. */
function endereco(valor: string, semCaminho: boolean): URL | null {
  try {
    const u = new URL(valor);
    const local = u.hostname === 'localhost' || u.hostname === '127.0.0.1';
    if (u.protocol !== 'https:' && !(u.protocol === 'http:' && local)) {
      return null;
    }
    if (u.username || u.password || u.hash || u.search) return null;
    if (semCaminho && u.pathname !== '/' && u.pathname !== '') return null;
    return u;
  } catch {
    return null;
  }
}

/**
 * A configuração, lida do ambiente (a distribuição configura no EasyPanel; nada disso é da
 * empresa):
 * - `GOGEM_REGEM_CLIQUE=true` liga o botão (sem isso, o cartão segue só com o token colado);
 * - `GOGEM_REGEM_API_URL` (a API do Regem, com o `/api/v1`), `GOGEM_REGEM_APP_URL` (o site do
 *   Regem) e `GOGEM_PAINEL_URL` (o painel do GoGeM): os padrões são os de produção;
 * - `DMS_ID_EMISSOR`, `DMS_ID_APLICATIVO` e `DMS_ID_SEGREDO`: o aplicativo do GoGeM no DMS ID.
 * Configuração torta não liga: o motivo vai ao log, para a distribuição.
 */
export function lerConfigDoClique(
  e: Record<string, string | undefined>,
): ConfigDoClique {
  const v = (e.GOGEM_REGEM_CLIQUE ?? '').trim().toLowerCase();
  if (v !== 'true' && v !== '1' && v !== 'sim') {
    return { ligado: false, motivo: null };
  }
  const desligado = (motivo: string): ConfigDoClique => ({
    ligado: false,
    motivo,
  });

  const api = endereco(
    (e.GOGEM_REGEM_API_URL || 'https://api.dmsregem.com/api/v1').trim(),
    false,
  );
  if (!api) {
    return desligado(
      'GOGEM_REGEM_API_URL precisa ser o endereço https da API do Regem',
    );
  }
  const site = endereco(
    (e.GOGEM_REGEM_APP_URL || 'https://app.dmsregem.com').trim(),
    true,
  );
  if (!site) {
    return desligado(
      'GOGEM_REGEM_APP_URL precisa ser o endereço https do site do Regem, sem caminho',
    );
  }
  const painel = endereco(
    (e.GOGEM_PAINEL_URL || 'https://app.gogem.com.br').trim(),
    true,
  );
  if (!painel) {
    return desligado(
      'GOGEM_PAINEL_URL precisa ser o endereço https do painel do GoGeM, sem caminho',
    );
  }

  const emissorDmsId = (e.DMS_ID_EMISSOR ?? '').trim().replace(/\/+$/, '');
  const aplicativo = (e.DMS_ID_APLICATIVO ?? '').trim();
  const segredo = (e.DMS_ID_SEGREDO ?? '').trim();
  for (const [nome, valor] of [
    ['DMS_ID_EMISSOR', emissorDmsId],
    ['DMS_ID_APLICATIVO', aplicativo],
    ['DMS_ID_SEGREDO', segredo],
  ] as const) {
    if (!valor) {
      return desligado(`falta ${nome} (o aplicativo do GoGeM no DMS ID)`);
    }
  }
  const base = `${api.origin}${api.pathname.replace(/\/+$/, '')}`;
  return {
    ligado: true,
    base,
    emissorDoRegem: api.origin,
    recurso: `${base}${CAMINHO_DA_PORTA}`,
    pagina: `${site.origin}${CAMINHO_DA_PAGINA}`,
    volta: `${painel.origin}${CAMINHO_DA_VOLTA}`,
    emissorDmsId,
    aplicativo,
    segredo,
  };
}

// ───────────────────────────── o pedido ─────────────────────────────

export const hashDoEstado = (estado: string): string =>
  createHash('sha256').update(estado, 'utf8').digest('hex');

/** O `state` (só o resumo é guardado) e o par do PKCE (o verificador fica cifrado no banco). */
export function gerarPedido(): {
  estado: string;
  estadoHash: string;
  verificador: string;
  desafio: string;
} {
  const estado = randomBytes(32).toString('base64url');
  const verificador = randomBytes(48).toString('base64url');
  return {
    estado,
    estadoHash: hashDoEstado(estado),
    verificador,
    desafio: createHash('sha256')
      .update(verificador, 'ascii')
      .digest('base64url'),
  };
}

const FORMATO_DO_ESTADO = /^[A-Za-z0-9_-]{43}$/;
export const formatoDoEstado = (v: unknown): v is string =>
  typeof v === 'string' && FORMATO_DO_ESTADO.test(v);

/** O CNPJ com 14 dígitos, ou nada (o Regem trata a conta sem CNPJ como de outra empresa). */
export function cnpjDaConta(bruto: string | null | undefined): string | null {
  const d = String(bruto ?? '').replace(/\D/g, '');
  return d.length === 14 ? d : null;
}

/** O corpo do pedido empurrado (`POST /integracao/autorizacao/pedido`). */
export function corpoDoPedido(d: {
  volta: string;
  estado: string;
  desafio: string;
  contaNome: string;
  contaCnpj: string | null;
  contaEmail: string;
}): Record<string, string> {
  return {
    response_type: 'code',
    redirect_uri: d.volta,
    scope: PERMISSOES_DO_TOTEM.join(' '),
    state: d.estado,
    code_challenge: d.desafio,
    code_challenge_method: 'S256',
    conta_nome: d.contaNome.trim().slice(0, 120) || 'Conta do GoGeM',
    ...(d.contaCnpj ? { conta_cnpj: d.contaCnpj } : {}),
    conta_email: d.contaEmail.trim().toLowerCase().slice(0, 200),
  };
}

const FORMATO_DO_NUMERO =
  /^urn:ietf:params:oauth:request_uri:rgm_[A-Za-z0-9_-]{43}$/;
export const formatoDoNumero = (v: unknown): v is string =>
  typeof v === 'string' && FORMATO_DO_NUMERO.test(v);

/** A página do Regem com o número do pedido: é para lá que o navegador vai. */
export function urlDaPagina(
  pagina: string,
  aplicativo: string,
  numero: string,
): string {
  const u = new URL(pagina);
  u.searchParams.set('client_id', aplicativo);
  u.searchParams.set('request_uri', numero);
  return u.toString();
}

// ───────────────────────────── a volta ─────────────────────────────

export type Volta =
  | { tipo: 'codigo'; estado: string; codigo: string }
  | {
      tipo: 'recusa';
      estado: string;
      motivo: 'recusado' | 'pedido_invalido';
    }
  | { tipo: 'invalida'; motivo: string };

const texto = (v: unknown) => (typeof v === 'string' ? v : '');

/**
 * Confere o que o navegador trouxe de volta, ANTES de ir ao banco. O `iss` tem de ser o do Regem
 * (RFC 9207): sem ele ou com outro, a volta não vale, mesmo com um `state` certo.
 */
export function conferirVolta(
  q: { code?: unknown; state?: unknown; iss?: unknown; error?: unknown },
  emissorDoRegem: string,
): Volta {
  if (texto(q.iss) !== emissorDoRegem) {
    return { tipo: 'invalida', motivo: 'a volta não veio do Regem' };
  }
  if (!formatoDoEstado(q.state)) {
    return {
      tipo: 'invalida',
      motivo: 'a volta veio sem o pedido que o GoGeM abriu',
    };
  }
  const erro = texto(q.error);
  if (erro) {
    return {
      tipo: 'recusa',
      estado: q.state,
      motivo: erro === 'access_denied' ? 'recusado' : 'pedido_invalido',
    };
  }
  const codigo = texto(q.code);
  if (codigo.length < 20 || codigo.length > 300 || /\s/.test(codigo)) {
    return {
      tipo: 'invalida',
      motivo: 'a volta veio sem o código da autorização',
    };
  }
  return { tipo: 'codigo', estado: q.state, codigo };
}

// ───────────────────────────── a troca ─────────────────────────────

export type LojaLigada = {
  lojaId: string;
  nome: string;
  ligacao: string;
  prefixo: string | null;
  permissoes: string[];
};

const FORMATO_DA_LIGACAO = /^dms_lg_regem_[A-Za-z0-9_-]{43}_[A-Za-z0-9_-]{6}$/;

/**
 * As lojas que a troca devolveu, conferidas: o segredo com a cara da ligação do Regem e as três
 * permissões do totem. Resposta torta (ou sem loja nenhuma) devolve `null`: nada é guardado.
 */
export function lojasDaTroca(resposta: unknown): LojaLigada[] | null {
  const lista = (resposta as { lojas?: unknown } | null)?.lojas;
  if (!Array.isArray(lista) || !lista.length || lista.length > 200) {
    return null;
  }
  const saida: LojaLigada[] = [];
  const vistas = new Set<string>();
  for (const bruto of lista) {
    const l = bruto as Record<string, unknown> | null;
    const lojaId = texto(l?.loja_id).trim();
    const ligacao = texto(l?.ligacao);
    const permissoes = Array.isArray(l?.permissoes)
      ? (l?.permissoes as unknown[]).filter(
          (p): p is string => typeof p === 'string',
        )
      : [];
    if (!lojaId || lojaId.length > 100 || vistas.has(lojaId)) return null;
    if (!FORMATO_DA_LIGACAO.test(ligacao)) return null;
    if (PERMISSOES_DO_TOTEM.some((p) => !permissoes.includes(p))) return null;
    vistas.add(lojaId);
    saida.push({
      lojaId,
      nome: (texto(l?.loja_nome).trim() || 'Loja do Regem').slice(0, 200),
      ligacao,
      prefixo: texto(l?.prefixo).slice(0, 40) || null,
      permissoes: permissoes.slice(0, 20),
    });
  }
  return saida;
}

/**
 * A loja em uso depois da troca: a que já estava em uso, se o presidente a marcou de novo; senão
 * a primeira (o Regem devolve a matriz antes). Com mais de uma, o painel deixa trocar (G-5).
 */
export function lojaEmUso(
  lojas: readonly LojaLigada[],
  atual: string | null | undefined,
): LojaLigada {
  return lojas.find((l) => l.lojaId === atual) ?? (lojas[0] as LojaLigada);
}
