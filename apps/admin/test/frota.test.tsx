import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import App from '@/App';
import { server } from '@/test/msw/server';
import { clearToken, setToken } from '@/lib/auth-token';
import { queryClient } from '@/lib/query';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

function usuario(papel: 'presidente' | 'gerente' | 'execucao') {
  return {
    id: 'u1',
    tenantId: 't1',
    unidadeId: null,
    email: 'chefe@loja.com.br',
    nome: 'Chefe',
    papel,
  };
}

const daqui20min = new Date(Date.now() + 20 * 60_000).toISOString();

const DISPOSITIVOS = [
  {
    id: 'd1',
    unidadeId: null,
    nome: 'Totem entrada',
    tipo: 'totem',
    pareado: false,
    codigoPareamento: '482913',
    codigoExpiraEm: daqui20min,
    ativo: true,
    createdAt: daqui20min,
    updatedAt: daqui20min,
  },
  {
    id: 'd2',
    unidadeId: null,
    nome: 'Totem caixa',
    tipo: 'totem',
    pareado: true,
    codigoPareamento: null,
    codigoExpiraEm: null,
    ativo: true,
    createdAt: daqui20min,
    updatedAt: daqui20min,
  },
];

function montar(papel: 'presidente' | 'gerente' | 'execucao' = 'gerente') {
  setToken('tok');
  server.use(http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))));
  window.history.pushState({}, '', '/frota');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Frota', () => {
  it('lista totens com status e código de pareamento', async () => {
    server.use(
      http.get(`${API}/dispositivos`, () => HttpResponse.json(DISPOSITIVOS)),
    );
    montar('gerente');

    expect(await screen.findByText('Totem entrada')).toBeInTheDocument();
    expect(screen.getByText('482913')).toBeInTheDocument(); // código do não-pareado
    expect(screen.getByText('Aguardando')).toBeInTheDocument();
    expect(screen.getByText('Pareado')).toBeInTheDocument(); // o d2
  });

  it('cadastra um totem e mostra o código de 6 dígitos', async () => {
    server.use(
      http.get(`${API}/dispositivos`, () => HttpResponse.json([])),
      http.post(`${API}/dispositivos`, () =>
        HttpResponse.json({
          id: 'novo',
          nome: 'Totem 1',
          codigoPareamento: '123456',
          codigoExpiraEm: daqui20min,
        }),
      ),
    );
    montar('gerente');

    fireEvent.click((await screen.findAllByRole('button', { name: 'Novo totem' }))[0]);
    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByLabelText('Nome do totem'), {
      target: { value: 'Totem 1' },
    });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Cadastrar' }));

    // aparece o diálogo do código grande
    expect(await screen.findByText('Código de pareamento')).toBeInTheDocument();
    expect(screen.getByText('123456')).toBeInTheDocument();
  });

  it('execução (somente leitura) não vê ação de novo totem', async () => {
    server.use(
      http.get(`${API}/dispositivos`, () => HttpResponse.json(DISPOSITIVOS)),
    );
    montar('execucao');

    expect(await screen.findByText('Totem entrada')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Novo totem' }),
    ).not.toBeInTheDocument();
  });
});
