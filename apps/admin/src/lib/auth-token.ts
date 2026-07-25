/**
 * Armazenamento simples do token JWT do backoffice.
 * Mantém uma cópia em memória (fonte rápida para o interceptor do axios)
 * espelhada em localStorage (sobrevive a reloads). A lógica de auth
 * completa (login/register/refresh) chega no PR B — aqui só o storage.
 */
const STORAGE_KEY = 'gogem.admin.token';

let inMemoryToken: string | null = null;

/** Lê o token: memória primeiro, caindo para o localStorage. */
export function getToken(): string | null {
  if (inMemoryToken) return inMemoryToken;
  try {
    inMemoryToken = localStorage.getItem(STORAGE_KEY);
  } catch {
    // localStorage indisponível (SSR/privado) — ignora.
  }
  return inMemoryToken;
}

/** Grava o token em memória + localStorage. */
export function setToken(token: string): void {
  inMemoryToken = token;
  try {
    localStorage.setItem(STORAGE_KEY, token);
  } catch {
    // ignora falha de storage
  }
}

/** Limpa o token (logout / resposta 401). */
export function clearToken(): void {
  inMemoryToken = null;
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // ignora falha de storage
  }
}
