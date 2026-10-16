import { createHash } from 'node:crypto';

/**
 * O banco guarda só o RESUMO do token do totem (`Dispositivo.tokenHash`), nunca
 * o token: quem lê o banco não consegue se passar por um totem. O token é
 * aleatório de 256 bits, então SHA-256 basta (não há o que adivinhar).
 *
 * O prefixo `sha256:` deixa a coluna autoexplicativa, separa o resumo do token
 * puro dos totens pareados antes (transição) e permite converter sem converter
 * duas vezes.
 */
export const PREFIXO_DO_RESUMO = 'sha256:';

export function resumoDoTokenDoDispositivo(token: string): string {
  return `${PREFIXO_DO_RESUMO}${createHash('sha256').update(token, 'utf8').digest('hex')}`;
}
