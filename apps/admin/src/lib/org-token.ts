/**
 * Storage do token JWT do **Console da Distribuição** (organização/DMS).
 * SEPARADO do token do cliente (`gogem.admin.token`) — o console e o admin do
 * lojista nunca compartilham sessão. Memória + localStorage (sobrevive reload).
 */
const STORAGE_KEY = 'gogem.org.token';

let inMemory: string | null = null;

export function getOrgToken(): string | null {
  if (inMemory) return inMemory;
  try {
    inMemory = localStorage.getItem(STORAGE_KEY);
  } catch {
    // storage indisponível
  }
  return inMemory;
}

export function setOrgToken(token: string): void {
  inMemory = token;
  try {
    localStorage.setItem(STORAGE_KEY, token);
  } catch {
    // ignora
  }
}

export function clearOrgToken(): void {
  inMemory = null;
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // ignora
  }
}
