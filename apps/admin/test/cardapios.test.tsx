import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import App from '@/App';
import { server } from '@/test/msw/server';
import { clearToken, setToken } from '@/lib/auth-token';
import { queryClient } from '@/lib/query';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

function usuario(papel: 'presidente' | 'gerente' | 'execucao') {
  return { id: 'u1', tenantId: 't1', unidadeId: null, email: 'c@l.com', nome: 'Chefe', papel };
}

const CARDAPIOS = [
  { id: 'c-ativo', nome: 'Cardápio padrão', ativo: true, ordem: 0, produtos: 12 },
  { id: 'c-novo', nome: 'Novo sistema', ativo: false, ordem: 1, produtos: 0 },
];

function montar(papel: 'presidente' | 'gerente' | 'execucao' = 'gerente') {
  setToken('tok');
  server.use(
    http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))),
    http.get(`${API}/cardapios`, () => HttpResponse.json(CARDAPIOS)),
  );
  window.history.pushState({}, '', '/cardapios');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Cardápios', () => {
  it('lista os cardápios com Ativo/Inativo e contagem', async () => {
    montar('gerente');
    expect(await screen.findByText('Cardápio padrão')).toBeInTheDocument();
    expect(screen.getByText('Novo sistema')).toBeInTheDocument();
    expect(screen.getByText('Ativo')).toBeInTheDocument();
    expect(screen.getByText('Inativo')).toBeInTheDocument();
    expect(screen.getByText(/12 produto/)).toBeInTheDocument();
  });

  it('cria um cardápio novo (modo duplicar)', async () => {
    let recebido: { nome?: string; modo?: string } | null = null;
    montar('gerente');
    server.use(
      http.post(`${API}/cardapios`, async ({ request }) => {
        recebido = (await request.json()) as typeof recebido;
        return HttpResponse.json({
          id: 'c-3',
          nome: recebido!.nome,
          ativo: false,
          ordem: 2,
          produtos: 0,
        });
      }),
    );

    fireEvent.click(await screen.findByRole('button', { name: 'Novo cardápio' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByLabelText('Nome'), {
      target: { value: 'Cópia teste' },
    });
    fireEvent.click(within(dialog).getByLabelText(/Duplicar o ativo/));
    fireEvent.click(within(dialog).getByRole('button', { name: 'Criar cardápio' }));

    await waitFor(() => expect(recebido).not.toBeNull());
    expect(recebido!.nome).toBe('Cópia teste');
    expect(recebido!.modo).toBe('duplicar');
  });

  it('ativa um cardápio inativo', async () => {
    let ativou = false;
    montar('gerente');
    server.use(
      http.post(`${API}/cardapios/c-novo/ativar`, () => {
        ativou = true;
        return HttpResponse.json({ ...CARDAPIOS[1], ativo: true });
      }),
    );

    fireEvent.click(await screen.findByRole('button', { name: 'Ativar' }));
    await waitFor(() => expect(ativou).toBe(true));
  });

  it('limite de 2: botão Novo cardápio fica desabilitado', async () => {
    montar('gerente');
    const btn = await screen.findByRole('button', { name: 'Novo cardápio' });
    // desabilita após os cardápios carregarem (2 = limite).
    await waitFor(() => expect(btn).toBeDisabled());
  });
});
