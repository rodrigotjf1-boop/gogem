import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Os AVISOS ASSINADOS do Regem ao GoGeM — contrato 1 (`AVISOS-ASSINADOS.md` do Regem, padrão
 * Standard Webhooks, o mesmo do Regem com o Liame e o Farol e do Padrão DMS de integração §9).
 *
 * O GoGeM GERA o segredo (`whsec_` + 32 bytes em base64), guarda cifrado na integração e o
 * registra no Regem com o token de integração da loja (`PUT /integracao/webhook`). O Regem assina
 * cada aviso; o GoGeM confere antes de qualquer coisa:
 *   `webhook-signature` = `v1,` + base64 do HMAC-SHA256 de `"<webhook-id>.<webhook-timestamp>.<corpo>"`,
 *   com a chave = o segredo DECODIFICADO do base64 (sem o `whsec_`), sobre o corpo EXATO recebido.
 *
 * Este arquivo é só a parte pura (sem banco): segredo, chave, endereço e a conferência.
 */

/** O prefixo do segredo no padrão Standard Webhooks. */
export const PREFIXO_DO_SEGREDO = 'whsec_';
/** Aviso com o relógio mais longe do que isto do nosso não vale (segundos) — o contrato pede 5 min. */
export const TOLERANCIA_S = 300;
/** Na troca do segredo, o anterior ainda vale por este tempo (um aviso que já estava saindo). */
export const JANELA_DO_ANTERIOR_MS = 10 * 60_000;
/** O registro aceito é refeito de tanto em tanto: religa o que o Regem tiver pausado. */
export const REGISTRAR_DE_NOVO_MS = 20 * 60 * 60_000;
/** Depois de uma tentativa que falhou, a próxima automática espera isto. */
export const ESPERA_ENTRE_TENTATIVAS_MS = 30 * 60_000;
/** O endereço público da API do GoGeM (o Regem só aceita registro dentro dele). */
export const URL_PUBLICA_PADRAO = 'https://api.gogem.com.br/api/v1';
/** O trecho do endereço que identifica a integração: até 64, só letras, números, `-` e `_`. */
export const ID_DO_ENDERECO = /^[A-Za-z0-9_-]{1,64}$/;
/** O campo do contexto da cifra do segredo (o anterior usa o mesmo, para poder só mudar de lugar). */
export const CAMPO_DO_SEGREDO = 'avisos';

/** O que fica na coluna `Integracao.avisos` (os segredos sempre cifrados). */
export interface EstadoDosAvisos {
  /** O segredo em uso, cifrado (`v1.…`). */
  segredo: string;
  /** O segredo anterior, cifrado — vale até `trocadoEm` + 10 min. */
  anterior?: string | null;
  trocadoEm?: string | null;
  /** SHA-256 do token de integração com que o registro foi feito (token novo = registro novo). */
  resumoDoToken: string;
  /** O último registro que o Regem aceitou. */
  registradoEm?: string | null;
  /** A última tentativa de registrar (deu certo ou não). */
  tentadoEm?: string | null;
  /** Por que a última tentativa não passou (sem segredo nenhum). */
  erro?: string | null;
}

/** Lê a coluna, tolerante a forma estranha: o que não serve é "sem avisos". */
export function lerEstadoDosAvisos(valor: unknown): EstadoDosAvisos | null {
  if (!valor || typeof valor !== 'object' || Array.isArray(valor)) return null;
  const v = valor as Record<string, unknown>;
  if (typeof v.segredo !== 'string' || typeof v.resumoDoToken !== 'string') {
    return null;
  }
  const texto = (x: unknown) => (typeof x === 'string' ? x : null);
  return {
    segredo: v.segredo,
    anterior: texto(v.anterior),
    trocadoEm: texto(v.trocadoEm),
    resumoDoToken: v.resumoDoToken,
    registradoEm: texto(v.registradoEm),
    tentadoEm: texto(v.tentadoEm),
    erro: texto(v.erro),
  };
}

/** Um segredo novo no formato que o Regem aceita: `whsec_` + 32 bytes em base64. */
export function novoSegredoDosAvisos(): string {
  return PREFIXO_DO_SEGREDO + randomBytes(32).toString('base64');
}

/** A chave (os bytes) de um segredo `whsec_…`; `null` se o formato não serve (24 a 64 bytes). */
export function chaveDoSegredo(
  segredo: string | null | undefined,
): Buffer | null {
  if (
    !segredo ||
    !segredo.startsWith(PREFIXO_DO_SEGREDO) ||
    segredo.length > 200
  ) {
    return null;
  }
  const b64 = segredo.slice(PREFIXO_DO_SEGREDO.length);
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(b64)) return null;
  const chave = Buffer.from(b64, 'base64');
  return chave.length >= 24 && chave.length <= 64 ? chave : null;
}

/** O endereço que o GoGeM registra no Regem para uma integração. */
export function enderecoDosAvisos(
  integracaoId: string,
  base: string = process.env.GOGEM_URL_PUBLICA_API || URL_PUBLICA_PADRAO,
): string {
  return `${base.replace(/\/$/, '')}/sync/regem/avisos/${integracaoId}`;
}

export type Conferencia =
  'ok' | 'sem_cabecalho' | 'fora_do_prazo' | 'assinatura';

/** A assinatura de um aviso (para os testes e para o "Regem falso"). */
export function assinarAviso(
  chave: Buffer,
  id: string,
  timestampSeg: number | string,
  corpo: string,
): string {
  return `v1,${createHmac('sha256', chave).update(`${id}.${timestampSeg}.${corpo}`, 'utf8').digest('base64')}`;
}

/**
 * Confere um aviso: os três cabeçalhos, o relógio (±5 min) e a assinatura sobre o texto EXATO
 * que chegou. O cabeçalho pode trazer mais de uma assinatura (separadas por espaço) e pode haver
 * mais de uma chave (a atual e a anterior, na troca): basta um par bater. Comparação em tempo
 * constante.
 */
export function conferirAvisoAssinado(p: {
  id: unknown;
  timestamp: unknown;
  assinatura: unknown;
  corpo: string;
  chaves: Buffer[];
  agora: Date;
}): Conferencia {
  const { id, timestamp, assinatura } = p;
  if (typeof id !== 'string' || id.length === 0 || id.length > 256) {
    return 'sem_cabecalho';
  }
  if (typeof timestamp !== 'string' || !/^[0-9]{1,12}$/.test(timestamp)) {
    return 'sem_cabecalho';
  }
  if (
    typeof assinatura !== 'string' ||
    assinatura.length === 0 ||
    assinatura.length > 2048
  ) {
    return 'sem_cabecalho';
  }
  if (Math.abs(p.agora.getTime() / 1000 - Number(timestamp)) > TOLERANCIA_S) {
    return 'fora_do_prazo';
  }

  const dadas: Buffer[] = [];
  for (const parte of assinatura.split(' ')) {
    const virgula = parte.indexOf(',');
    if (virgula < 0 || parte.slice(0, virgula) !== 'v1') continue;
    dadas.push(Buffer.from(parte.slice(virgula + 1), 'base64'));
  }

  for (const chave of p.chaves) {
    const esperada = createHmac('sha256', chave)
      .update(`${id}.${timestamp}.${p.corpo}`, 'utf8')
      .digest();
    for (const dada of dadas) {
      if (dada.length === esperada.length && timingSafeEqual(dada, esperada)) {
        return 'ok';
      }
    }
  }
  return 'assinatura';
}
