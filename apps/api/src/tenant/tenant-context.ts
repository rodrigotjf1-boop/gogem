import { AsyncLocalStorage } from 'node:async_hooks';

/**
 * Conteúdo do contexto de tenant da requisição corrente.
 * `tenantId` é obrigatório; `userId`/`papel` acompanham quando há usuário.
 */
export interface TenantStore {
  tenantId: string;
  userId?: string;
  papel?: string;
}

/**
 * TenantContext — contexto multi-tenant por requisição (CLAUDE.md §2).
 *
 * Usa AsyncLocalStorage: um interceptor abre o escopo DEPOIS da auth resolver
 * o usuário (`TenantContext.run`), e o middleware do Prisma lê `getTenantId()`
 * para injetar o filtro de tenant em toda query. Se não houver tenant no
 * contexto, o Prisma falha fechado.
 *
 * Escape hatch de sistema (`runAsSystem`): operações de bootstrap que precisam
 * rodar ANTES de existir um contexto de tenant — `register` (cria o 1º tenant +
 * usuário) e `login` (busca o usuário por e-mail globalmente). Dentro dele o
 * middleware não exige tenant no contexto; por isso o chamador é obrigado a
 * passar o `tenantId` explicitamente nos `data`.
 */
const storage = new AsyncLocalStorage<TenantStore>();
const systemStorage = new AsyncLocalStorage<true>();

export class TenantContext {
  /** Roda `fn` dentro do escopo de tenant informado. */
  static run<T>(store: TenantStore, fn: () => T): T {
    return storage.run(store, fn);
  }

  /**
   * Roda `fn` como operação de sistema (bootstrap): o escopo de tenant do
   * Prisma é dispensado. Use APENAS quando o tenant é fornecido à mão nos
   * dados (register/login). Ver docstring da classe.
   */
  static runAsSystem<T>(fn: () => T): T {
    return systemStorage.run(true, fn);
  }

  /** Store atual (ou `undefined` fora de uma requisição com tenant). */
  static get(): TenantStore | undefined {
    return storage.getStore();
  }

  /** `tenantId` atual, ou `null` se não houver contexto de tenant. */
  static getTenantId(): string | null {
    return storage.getStore()?.tenantId ?? null;
  }

  /** `true` quando dentro de `runAsSystem` (escape hatch de bootstrap). */
  static isSystem(): boolean {
    return systemStorage.getStore() === true;
  }
}
