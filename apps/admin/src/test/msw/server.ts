import { setupServer } from 'msw/node';

/**
 * Servidor MSW para os testes. Sem handlers por enquanto — cada suíte de
 * teste registra os seus com `server.use(...)`. Endpoints reais chegam nos
 * PRs de funcionalidade.
 */
export const handlers = [];

export const server = setupServer(...handlers);
