import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

/**
 * Cifra simétrica dos segredos guardados no banco (AES-256-GCM), no mesmo
 * formato usado nos outros produtos DMS: `v1.<número>.<marca>.<corpo>`, cada
 * parte em base64url. O `contexto` entra como dado associado (AAD): o texto
 * cifrado de uma linha não abre em outra (outra empresa, loja ou campo).
 *
 * A marca de autenticação é fixada em 16 bytes na decifra também — sem isso o
 * Node aceita marca curta e a falsificação fica barata.
 */

const VERSAO = 'v1';
const ALGORITMO = 'aes-256-gcm';
const TAMANHO_DA_CHAVE = 32;
const TAMANHO_DA_MARCA = 16;

/** Lê a chave (32 bytes em base64 ou base64url). Formato errado = null. */
export function lerChave(valor: string | undefined): Buffer | null {
  const limpo = (valor ?? '').trim();
  if (!/^[A-Za-z0-9+/_-]+={0,2}$/.test(limpo)) return null;
  const chave = Buffer.from(limpo, 'base64');
  return chave.length === TAMANHO_DA_CHAVE ? chave : null;
}

/** O valor tem a forma de um texto cifrado por `cifrar`? */
export function ehCifrado(valor: unknown): boolean {
  if (typeof valor !== 'string') return false;
  const partes = valor.split('.');
  return partes.length === 4 && partes[0] === VERSAO;
}

export function cifrar(claro: string, chave: Buffer, contexto: string): string {
  const numero = randomBytes(12);
  const c = createCipheriv(ALGORITMO, chave, numero, {
    authTagLength: TAMANHO_DA_MARCA,
  });
  c.setAAD(Buffer.from(contexto, 'utf8'));
  const corpo = Buffer.concat([c.update(claro, 'utf8'), c.final()]);
  return [
    VERSAO,
    numero.toString('base64url'),
    c.getAuthTag().toString('base64url'),
    corpo.toString('base64url'),
  ].join('.');
}

/** Decifra; qualquer falha (chave, contexto, marca, formato) = null. */
export function decifrar(
  cifrado: string,
  chave: Buffer,
  contexto: string,
): string | null {
  const partes = String(cifrado ?? '').split('.');
  if (partes.length !== 4 || partes[0] !== VERSAO) return null;
  try {
    const d = createDecipheriv(
      ALGORITMO,
      chave,
      Buffer.from(partes[1]!, 'base64url'),
      { authTagLength: TAMANHO_DA_MARCA },
    );
    d.setAAD(Buffer.from(contexto, 'utf8'));
    d.setAuthTag(Buffer.from(partes[2]!, 'base64url'));
    return Buffer.concat([
      d.update(Buffer.from(partes[3]!, 'base64url')),
      d.final(),
    ]).toString('utf8');
  } catch {
    return null;
  }
}
