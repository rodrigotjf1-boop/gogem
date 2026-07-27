import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
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

const CATEGORIA = { id: 'c1', nome: 'Lanches', ordem: 0 };
const PRODUTO = {
  id: 'p1',
  nome: 'X-Salada',
  descricao: 'Pão, hambúrguer e salada.',
  precoCentavos: 2590,
  disponivel: true,
  categoriaId: 'c1',
  externalRefs: [{ sistema: 'regem', codigo_pdv: 'PROD-001' }],
};

/** Boot autenticado em /catalogo com o papel informado. */
function montarLogado(papel: 'presidente' | 'gerente' | 'execucao' = 'gerente') {
  setToken('tok-teste');
  server.use(http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))));
  window.history.pushState({}, '', '/catalogo');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Catálogo — leitura', () => {
  it('lista produtos com preço, categoria e código PDV', async () => {
    server.use(
      http.get(`${API}/categorias`, () => HttpResponse.json([CATEGORIA])),
      http.get(`${API}/produtos`, () => HttpResponse.json([PRODUTO])),
    );
    montarLogado('gerente');

    expect(await screen.findByText('X-Salada')).toBeInTheDocument();
    expect(screen.getByText(/25,90/)).toBeInTheDocument();
    expect(screen.getByText('PROD-001')).toBeInTheDocument();
    // "Lanches" aparece no filtro (option) e na coluna Categoria da tabela.
    expect(screen.getAllByText('Lanches').length).toBeGreaterThan(0);
    expect(screen.getByText('Disponível')).toBeInTheDocument();
  });

  it('mostra estado vazio quando não há produtos', async () => {
    server.use(
      http.get(`${API}/categorias`, () => HttpResponse.json([])),
      http.get(`${API}/produtos`, () => HttpResponse.json([])),
    );
    montarLogado('gerente');

    expect(
      await screen.findByText('Nenhum produto por aqui'),
    ).toBeInTheDocument();
  });
});

describe('Catálogo — RBAC no front', () => {
  it('execução (somente leitura) não vê ação de novo produto', async () => {
    server.use(
      http.get(`${API}/categorias`, () => HttpResponse.json([CATEGORIA])),
      http.get(`${API}/produtos`, () => HttpResponse.json([PRODUTO])),
    );
    montarLogado('execucao');

    expect(await screen.findByText('X-Salada')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Novo produto' }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: /Editar X-Salada/ }),
    ).not.toBeInTheDocument();
  });
});

describe('Catálogo — criar categoria', () => {
  it('cria uma categoria e ela aparece na lista', async () => {
    const categorias: Array<{ id: string; nome: string; ordem: number }> = [];
    server.use(
      http.get(`${API}/categorias`, () => HttpResponse.json(categorias)),
      http.get(`${API}/produtos`, () => HttpResponse.json([])),
      http.post(`${API}/categorias`, async ({ request }) => {
        const body = (await request.json()) as { nome: string; ordem: number };
        const nova = { id: 'c-nova', nome: body.nome, ordem: body.ordem };
        categorias.push(nova);
        return HttpResponse.json(nova);
      }),
    );
    montarLogado('gerente');

    // Vai para a aba Categorias.
    fireEvent.click(await screen.findByRole('tab', { name: 'Categorias' }));

    // Abre o formulário (há dois CTAs "Nova categoria": header + estado vazio).
    fireEvent.click(
      (await screen.findAllByRole('button', { name: 'Nova categoria' }))[0],
    );

    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByLabelText('Nome'), {
      target: { value: 'Bebidas' },
    });
    fireEvent.click(
      within(dialog).getByRole('button', { name: 'Criar categoria' }),
    );

    // Após salvar: o diálogo fecha e a nova categoria aparece na tabela.
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(await screen.findByText('Bebidas')).toBeInTheDocument();
  });
});
