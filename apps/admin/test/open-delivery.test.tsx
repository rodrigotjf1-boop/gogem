import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import App from '@/App';
import { server } from '@/test/msw/server';
import { clearToken, setToken } from '@/lib/auth-token';
import { queryClient } from '@/lib/query';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

function usuario(papel: 'gerente' | 'execucao') {
  return {
    id: 'u1',
    tenantId: 't1',
    unidadeId: null,
    email: 'chefe@loja.com.br',
    nome: 'Chefe',
    papel,
  };
}

function montar(papel: 'gerente' | 'execucao' = 'gerente') {
  setToken('tok');
  server.use(http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))));
  window.history.pushState({}, '', '/open-delivery');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Open Delivery (apps)', () => {
  it('cria um app e mostra o clientSecret uma vez', async () => {
    let recebido: { nome?: string; escopos?: string[] } | null = null;
    server.use(
      http.get(`${API}/open-delivery-apps`, () => HttpResponse.json([])),
      http.post(`${API}/open-delivery-apps`, async ({ request }) => {
        recebido = (await request.json()) as typeof recebido;
        return HttpResponse.json({
          id: 'a1',
          nome: recebido!.nome,
          clientId: 'od_abc123',
          clientSecret: 'super-secreto-xyz',
          escopos: recebido!.escopos,
          ativo: true,
        });
      }),
    );
    montar('gerente');

    fireEvent.click(await screen.findByRole('button', { name: 'Novo app' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByLabelText('Nome do parceiro'), {
      target: { value: 'iFood' },
    });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Criar app' }));

    // Diálogo de credenciais mostra o secret.
    expect(await screen.findByText('super-secreto-xyz')).toBeInTheDocument();
    expect(screen.getByText('od_abc123')).toBeInTheDocument();
    expect(recebido!.nome).toBe('iFood');
    expect(recebido!.escopos).toEqual(['catalog:read', 'orders:write']);
  });

  it('execução (somente leitura) não vê ação de novo app', async () => {
    server.use(
      http.get(`${API}/open-delivery-apps`, () =>
        HttpResponse.json([
          {
            id: 'a1',
            nome: 'Parceiro',
            clientId: 'od_x',
            escopos: ['catalog:read'],
            ativo: true,
            ultimoUso: null,
            createdAt: '2026-07-31T00:00:00.000Z',
          },
        ]),
      ),
    );
    montar('execucao');

    expect(await screen.findByText('Parceiro')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Novo app' }),
    ).not.toBeInTheDocument();
  });
});
