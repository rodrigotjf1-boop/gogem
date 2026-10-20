/* eslint-disable @typescript-eslint/no-explicit-any */

/**
 * O porquê de uma falha de rede, em texto curto, para o log e para a mensagem
 * ("ENOTFOUND api-stg.gogem.com.br", "ECONNREFUSED 10.0.0.5:443", "tempo esgotado").
 *
 * O `fetch` do Node (undici) lança só "fetch failed": o motivo está em `err.cause`
 * (`code`, `message` e às vezes `hostname`/`address`/`port`). Sem isto o motivo real
 * fica escondido — foi o que aconteceu no Regem (ERR-239 de lá, LIC-003): uma env
 * apontando para um host que não existe aparecia só como "fetch failed".
 *
 * Nunca leva cabeçalho, token nem a URL: só o código e o host/endereço — ou a
 * mensagem da causa, sem nada que pareça query e cortada. `null` = não há causa de
 * rede para contar.
 */
export function causaDeRede(e: unknown): string | null {
  const cadeia: any[] = [];
  for (let atual: any = e, i = 0; atual && i < 5; atual = atual.cause, i++) {
    cadeia.push(atual);
  }
  const esgotou = cadeia.some(
    (x) => x?.name === 'TimeoutError' || x?.name === 'AbortError',
  );
  // A causa mais funda que diz alguma coisa.
  const causa = [...cadeia]
    .reverse()
    .find((x) => x && typeof x === 'object' && (x.code || x.message));
  const codigo = typeof causa?.code === 'string' ? causa.code : null;
  const mensagem =
    typeof causa?.message === 'string' ? limpar(causa.message) : '';
  if (codigo) {
    const alvo =
      (typeof causa.hostname === 'string' && causa.hostname) ||
      (typeof causa.address === 'string' &&
        `${causa.address}${causa.port ? `:${causa.port}` : ''}`) ||
      mensagem.match(new RegExp(`\\b${codigo}\\s+(\\S+)`))?.[1] ||
      '';
    if (alvo) return `${codigo} ${alvo}`;
    return mensagem && mensagem !== 'fetch failed'
      ? `${codigo}: ${mensagem}`
      : codigo;
  }
  if (esgotou) return 'tempo esgotado';
  // Sem código: a mensagem da causa só conta se diz mais que o próprio erro.
  if (causa && causa !== e && mensagem && mensagem !== 'fetch failed') {
    return mensagem;
  }
  return null;
}

/** Sem query de URL (pode levar token) e no máximo 160 caracteres. */
function limpar(t: string): string {
  return t.replace(/\?\S*/g, '').replace(/\s+/g, ' ').trim().slice(0, 160);
}
