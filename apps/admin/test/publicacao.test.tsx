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

/** Lista de conectores como a API a devolve (segredos mascarados). */
const INTEGRACOES = [
  {
    tipo: 'regem',
    nome: 'Regem',
    descricao: 'ERP da família DMS.',
    disponivel: true,
    importaCatalogo: true,
    ativo: true,
    configurado: true,
    campos: [
      { key: 'apiBase', label: 'URL da API', secret: false, url: true, preenchido: true, valor: 'https://api.x/api/v1' },
      { key: 'token', label: 'Token de sincronização', secret: true, preenchido: true, valor: '••••••••' },
    ],
    nomePersonalizado: null,
    ultimoTeste: null,
  },
  {
    tipo: 'open_delivery',
    nome: 'Open Delivery',
    descricao: 'Padrão aberto de delivery.',
    disponivel: false,
    importaCatalogo: true,
    ativo: false,
    configurado: false,
    campos: [],
    nomePersonalizado: null,
    ultimoTeste: null,
  },
];

function comIntegracoes() {
  server.use(
    http.get(`${API}/integracoes`, () => HttpResponse.json(INTEGRACOES)),
  );
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Integrações', () => {
  it('lista os conectores (Regem ativo; Open Delivery em breve)', async () => {
    comIntegracoes();
    montar('/integracoes', 'gerente');

    // Âncora assíncrona = "Ativo" (status do conector Regem, só após a query).
    // "Open Delivery" agora também está no menu lateral, então usamos getAllByText.
    expect(await screen.findByText('Ativo')).toBeInTheDocument();
    expect(screen.getByText('Em breve')).toBeInTheDocument();
    expect(screen.getAllByText('Open Delivery').length).toBeGreaterThan(0);
  });

  it('importa o catálogo pelo conector Regem e mostra o resumo', async () => {
    comIntegracoes();
    server.use(
      http.post(`${API}/integracoes/regem/importar`, () =>
        HttpResponse.json(RESUMO),
      ),
    );
    montar('/integracoes', 'gerente');

    // Regem está ativo → seu botão de importar está habilitado (o do Open
    // Delivery está desabilitado por ser "em breve").
    const botoes = await screen.findAllByRole('button', {
      name: 'Importar catálogo',
    });
    const habilitado = botoes.find((b) => !(b as HTMLButtonElement).disabled)!;
    fireEvent.click(habilitado);

    expect(await screen.findByText('Import concluído')).toBeInTheDocument();
    expect(screen.getByText(/5\+\/3~/)).toBeInTheDocument(); // produtos
  });

  it('/importar redireciona para a área de Integrações', async () => {
    comIntegracoes();
    montar('/importar', 'gerente');
    expect(
      await screen.findByRole('heading', { name: 'Integrações' }),
    ).toBeInTheDocument();
    expect(await screen.findByText('Open Delivery')).toBeInTheDocument();
  });

  it('execução vê os cards mas sem poder configurar', async () => {
    comIntegracoes();
    montar('/integracoes', 'execucao');
    const configurar = await screen.findAllByRole('button', {
      name: 'Configurar',
    });
    expect(configurar[0]).toBeDisabled();
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
