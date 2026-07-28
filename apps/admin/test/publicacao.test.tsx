import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
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

function montar(
  path: string,
  papel: 'presidente' | 'gerente' | 'execucao' = 'gerente',
) {
  setToken('tok');
  server.use(http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))));
  window.history.pushState({}, '', path);
  render(<App />);
}

const RESUMO = {
  geradoEm: '2026-07-28T00:00:00.000Z',
  categorias: { criadas: 2, atualizadas: 1 },
  produtos: { criados: 5, atualizados: 3, ignoradosSemCodigo: 1 },
  grupos: { criados: 0, atualizados: 0 },
  opcoes: { criados: 4, atualizados: 0 },
};

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Importar do Regem', () => {
  it('importa e mostra o resumo com criados/atualizados', async () => {
    server.use(
      http.post(`${API}/import/regem`, () => HttpResponse.json(RESUMO)),
    );
    montar('/importar', 'gerente');

    fireEvent.click(
      await screen.findByRole('button', { name: 'Importar do Regem' }),
    );

    expect(await screen.findByText('Import concluído')).toBeInTheDocument();
    // produtos: 5 criados / 3 atualizados
    expect(screen.getByText('Produtos')).toBeInTheDocument();
    expect(screen.getByText('5')).toBeInTheDocument();
    expect(
      screen.getByText(/1 produto\(s\) do Regem foram ignorados/),
    ).toBeInTheDocument();
  });

  it('execução não vê o botão de importar', async () => {
    montar('/importar', 'execucao');
    expect(
      await screen.findByText('Apenas gerentes ou acima podem importar.'),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Importar do Regem' }),
    ).not.toBeInTheDocument();
  });

  it('erro 400 (Regem não configurado) aparece como alerta', async () => {
    server.use(
      http.post(`${API}/import/regem`, () =>
        HttpResponse.json(
          { message: 'Integração Regem não configurada', statusCode: 400 },
          { status: 400 },
        ),
      ),
    );
    montar('/importar', 'gerente');

    fireEvent.click(
      await screen.findByRole('button', { name: 'Importar do Regem' }),
    );

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(
        'Integração Regem não configurada',
      );
    });
  });
});

describe('Publicar', () => {
  it('lista versões e marca a última como No ar', async () => {
    server.use(
      http.get(`${API}/catalogo/versoes`, () =>
        HttpResponse.json([
          { id: 'b', versao: 2, publishedAt: '2026-07-28T10:00:00.000Z', publishedById: 'u1' },
          { id: 'a', versao: 1, publishedAt: '2026-07-27T10:00:00.000Z', publishedById: 'u1' },
        ]),
      ),
    );
    montar('/publicar', 'gerente');

    expect(
      await screen.findByText('Versão publicada atual: v2'),
    ).toBeInTheDocument();
    expect(screen.getByText('No ar')).toBeInTheDocument();
    expect(screen.getByText('Anterior')).toBeInTheDocument();
  });

  it('publica uma nova versão e mostra o resultado', async () => {
    let publicou = false;
    server.use(
      http.get(`${API}/catalogo/versoes`, () =>
        HttpResponse.json(
          publicou
            ? [{ id: 'a', versao: 1, publishedAt: '2026-07-28T10:00:00.000Z', publishedById: 'u1' }]
            : [],
        ),
      ),
      http.post(`${API}/catalogo/publicar`, () => {
        publicou = true;
        return HttpResponse.json({
          versao: 1,
          publishedAt: '2026-07-28T10:00:00.000Z',
          totais: { categorias: 3, produtos: 7, grupos: 2, opcoes: 5 },
        });
      }),
    );
    montar('/publicar', 'gerente');

    fireEvent.click(
      await screen.findByRole('button', { name: 'Publicar nova versão' }),
    );

    await waitFor(() => {
      expect(screen.getByRole('status')).toHaveTextContent('v1');
    });
    // a lista recarrega e mostra a nova versão (v1 aparece no status, no
    // cabeçalho e na linha da tabela → ≥2 ocorrências confirmam o reload).
    await waitFor(() => {
      expect(screen.getAllByText('v1').length).toBeGreaterThanOrEqual(2);
    });
  });
});
