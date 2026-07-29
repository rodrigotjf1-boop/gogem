import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

/**
 * Handlers default do MSW. O Shell (autenticado) chama `GET /cardapios` em toda
 * página (seletor de cardápio, Fase 3B), então respondemos um cardápio ativo
 * padrão aqui — as suítes que precisarem sobrescrevem com `server.use(...)`.
 * Os demais endpoints continuam por suíte.
 */
export const handlers = [
  http.get(`${API}/cardapios`, () =>
    HttpResponse.json([
      { id: 'card-ativo', nome: 'Cardápio padrão', ativo: true, ordem: 0, produtos: 0 },
    ]),
  ),
];

export const server = setupServer(...handlers);
