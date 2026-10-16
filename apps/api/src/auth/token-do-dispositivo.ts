import { createHash } from 'node:crypto';

/**
 * O banco guarda só o RESUMO do token do totem (`Dispositivo.tokenHash`), nunca
 * o token: quem lê o banco não consegue se passar por um totem. O token é
 * aleatório de 256 bits, então SHA-256 basta (não há o que adivinhar).
 *
 * O prefixo `sha256:` deixa a coluna autoexplicativa e permite à migration
 * converter os tokens antigos sem converter duas vezes.
 */
export function resumoDoTokenDoDispositivo(token: string): string {
  return `sha256:${createHash('sha256').update(token, 'utf8').digest('hex')}`;
}
