import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Assinatura dos avisos (webhooks) do Mercado Pago, pela documentação oficial
 * ("Suas integrações → Webhooks", validação da origem):
 *
 * - o cabeçalho `x-signature` traz `ts=<instante>,v1=<assinatura>`;
 * - o texto assinado é `id:[data.id da query];request-id:[x-request-id];ts:[ts];`
 *   — o `data.id` alfanumérico vai em minúsculas, e o que não veio no aviso
 *   (data.id ou x-request-id) sai do texto;
 * - a assinatura é o HMAC-SHA256 em hexadecimal desse texto, com a assinatura
 *   secreta da aplicação como chave.
 *
 * Vale para os avisos configurados em "Suas integrações" (pagamento PIX pela
 * API de pagamentos, Point). Não vale para QR Code de loja, que o GoGeM não usa.
 */

/** As duas partes do `x-signature`, ou null se faltar alguma. */
export function lerXSignature(
  bruto: string | undefined | null,
): { ts: string; v1: string } | null {
  let ts = '';
  let v1 = '';
  for (const parte of String(bruto ?? '').split(',')) {
    const i = parte.indexOf('=');
    if (i < 0) continue;
    const chave = parte.slice(0, i).trim();
    const valor = parte.slice(i + 1).trim();
    if (chave === 'ts') ts = valor;
    else if (chave === 'v1') v1 = valor;
  }
  return ts && v1 ? { ts, v1 } : null;
}

/** O texto que o Mercado Pago assinou. */
export function manifestoDoAviso(
  dataId: string | undefined | null,
  requestId: string | undefined | null,
  ts: string,
): string {
  let m = '';
  if (dataId) {
    m += `id:${/[a-z]/i.test(dataId) ? dataId.toLowerCase() : dataId};`;
  }
  if (requestId) m += `request-id:${requestId};`;
  m += `ts:${ts};`;
  return m;
}

/** O `data.id` da query do aviso (o que entra no texto assinado). */
export function dataIdDaQuery(query: Record<string, unknown>): string | null {
  const v = query['data.id'];
  const id = Array.isArray(v) ? v[0] : v;
  return id === undefined || id === null || id === '' ? null : String(id);
}

/** O aviso veio do Mercado Pago? Sem segredo configurado = não. */
export function avisoAutentico(opts: {
  xSignature: string | undefined | null;
  xRequestId: string | undefined | null;
  dataId: string | undefined | null;
  segredo: string | undefined | null;
}): boolean {
  if (!opts.segredo) return false;
  const cab = lerXSignature(opts.xSignature);
  if (!cab) return false;
  const esperado = createHmac('sha256', opts.segredo)
    .update(manifestoDoAviso(opts.dataId, opts.xRequestId, cab.ts))
    .digest('hex');
  const a = Buffer.from(esperado, 'utf8');
  const b = Buffer.from(cab.v1.toLowerCase(), 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}
