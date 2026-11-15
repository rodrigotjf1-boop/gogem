import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import App from '@/App';
import { server } from '@/test/msw/server';
import { clearToken, setToken } from '@/lib/auth-token';
import { queryClient } from '@/lib/query';
import { enderecoDoRegem } from '@/lib/integracoes';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

const GERENTE = {
  id: 'u1',
  tenantId: 't1',
  unidadeId: null,
  email: 'chefe@loja.com.br',
  nome: 'Chefe',
  papel: 'gerente',
};

const NAO_CONECTADO = {
  disponivel: true,
  conectado: false,
  emUso: null,
  lojas: [],
  conectadoEm: null,
};

const DUAS_LOJAS = {
  disponivel: true,
  conectado: true,
  emUso: { id: 'l1', nome: 'Brasa Centro' },
  lojas: [
    { id: 'l1', nome: 'Brasa Centro' },
    { id: 'l2', nome: 'Brasa Praia' },
  ],
  conectadoEm: '2026-11-15T03:00:00.000Z',
};

const regem = (clique: unknown) => ({
  tipo: 'regem',
  nome: 'Regem',
  descricao: 'ERP da família DMS.',
  disponivel: true,
  importaCatalogo: true,
  ativo: true,
  configurado: true,
  campos: [],
  nomePersonalizado: null,
  ultimoTeste: null,
  avisos: null,
  clique,
});

function montar(clique: unknown) {
  setToken('tok');
  server.use(
    http.get(`${API}/auth/me`, () => HttpResponse.json(GERENTE)),
    http.get(`${API}/integracoes`, () => HttpResponse.json([regem(clique)])),
    http.get(`${API}/cardapios`, () => HttpResponse.json([])),
  );
  window.history.pushState({}, '', '/integracoes');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Integrações — "Conectar pelo Regem" no cartão', () => {
  it('não conectado: o botão pede a página ao servidor e vai para o Regem', async () => {
    let chamou = 0;
    server.use(
      http.post(`${API}/integracoes/regem/clique`, () => {
        chamou += 1;
        return HttpResponse.json({
          url: 'https://app.dmsregem.com/integracoes/autorizar?client_id=gogem&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Aabc',
        });
      }),
    );
    montar(NAO_CONECTADO);

    expect(
      await screen.findByText(/Você não copia nenhum token/),
    ).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole('button', { name: 'Conectar pelo Regem' }),
    );
    expect(
      await screen.findByRole('button', { name: 'Indo para o Regem…' }),
    ).toBeDisabled();
    expect(chamou).toBe(1);
  });

  it('endereço que não é o do Regem em https: não vai e explica', async () => {
    server.use(
      http.post(`${API}/integracoes/regem/clique`, () =>
        HttpResponse.json({ url: 'javascript:alert(1)' }),
      ),
    );
    montar(NAO_CONECTADO);

    fireEvent.click(
      await screen.findByRole('button', { name: 'Conectar pelo Regem' }),
    );
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'O endereço do Regem veio errado',
    );
    expect(
      screen.getByRole('button', { name: 'Conectar pelo Regem' }),
    ).toBeEnabled();
  });

  it('a recusa do servidor aparece no cartão', async () => {
    server.use(
      http.post(`${API}/integracoes/regem/clique`, () =>
        HttpResponse.json(
          {
            message: 'O Regem não respondeu. Tente de novo em alguns minutos.',
          },
          { status: 503 },
        ),
      ),
    );
    montar(NAO_CONECTADO);

    fireEvent.click(
      await screen.findByRole('button', { name: 'Conectar pelo Regem' }),
    );
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'O Regem não respondeu',
    );
  });

  it('conectado com duas lojas: mostra a loja em uso e troca pela lista', async () => {
    let corpo: unknown = null;
    server.use(
      http.post(`${API}/integracoes/regem/clique/loja`, async ({ request }) => {
        corpo = await request.json();
        return HttpResponse.json({
          ...DUAS_LOJAS,
          emUso: { id: 'l2', nome: 'Brasa Praia' },
        });
      }),
    );
    montar(DUAS_LOJAS);

    expect(await screen.findByText(/Conectado pelo Regem:/)).toHaveTextContent(
      'Conectado pelo Regem: Brasa Centro.',
    );
    const lista = screen.getByRole('combobox', {
      name: 'Loja do Regem em uso',
    });
    fireEvent.change(lista, { target: { value: 'l2' } });

    expect(await screen.findByRole('status')).toHaveTextContent(
      'Agora as vendas do totem entram em Brasa Praia.',
    );
    expect(corpo).toEqual({ lojaId: 'l2' });
    // Conectado, o botão continua com o mesmo nome: é o caminho que a recusa aponta.
    expect(
      screen.getByRole('button', { name: 'Conectar pelo Regem' }),
    ).toBeInTheDocument();
  });

  it('servidor sem o clique ligado e nada conectado: o bloco não aparece', async () => {
    montar({ ...NAO_CONECTADO, disponivel: false });

    expect(await screen.findByText('ERP da família DMS.')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Conectar pelo Regem' }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/Você não copia nenhum token/)).toBeNull();
  });
});

describe('Integrações — a volta do Regem', () => {
  function voltar(busca: string) {
    setToken('tok');
    server.use(http.get(`${API}/auth/me`, () => HttpResponse.json(GERENTE)));
    window.history.pushState({}, '', `/integracoes/regem/volta${busca}`);
    render(<App />);
  }

  it('conectado: repassa a volta tal como veio e tira o código da barra', async () => {
    let corpo: unknown = null;
    server.use(
      http.post(
        `${API}/integracoes/regem/clique/volta`,
        async ({ request }) => {
          corpo = await request.json();
          return HttpResponse.json({
            situacao: 'conectado',
            clique: DUAS_LOJAS,
            avisos: 'Avisos do Regem: ligados (assinados).',
          });
        },
      ),
    );
    voltar(
      '?code=c-123&state=s-456&iss=https%3A%2F%2Fapi.dmsregem.com%2Fapi%2Fv1',
    );

    expect(
      await screen.findByRole('heading', {
        name: 'Pronto: conectado pelo Regem',
      }),
    ).toBeInTheDocument();
    expect(corpo).toEqual({
      code: 'c-123',
      state: 's-456',
      iss: 'https://api.dmsregem.com/api/v1',
    });
    expect(screen.getByText(/Você ligou 2 lojas/)).toBeInTheDocument();
    expect(window.location.search).toBe('');
    expect(
      screen.getByRole('link', { name: 'Ver a integração' }),
    ).toHaveAttribute('href', '/integracoes');
  });

  it('o presidente não autorizou: nada foi ligado', async () => {
    let corpo: unknown = null;
    server.use(
      http.post(
        `${API}/integracoes/regem/clique/volta`,
        async ({ request }) => {
          corpo = await request.json();
          return HttpResponse.json({ situacao: 'recusado' });
        },
      ),
    );
    voltar('?error=access_denied&state=s-456');

    expect(
      await screen.findByRole('heading', { name: 'Nada foi ligado' }),
    ).toBeInTheDocument();
    expect(corpo).toEqual({ error: 'access_denied', state: 's-456' });
  });

  it('a recusa do servidor aparece com o motivo', async () => {
    server.use(
      http.post(`${API}/integracoes/regem/clique/volta`, () =>
        HttpResponse.json(
          {
            message:
              'Este pedido de conexão não vale mais: já foi usado, venceu ou foi aberto por outra pessoa. Comece de novo pelo botão "Conectar pelo Regem".',
          },
          { status: 400 },
        ),
      ),
    );
    voltar('?code=c-123&state=s-velho');

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Este pedido de conexão não vale mais',
    );
  });

  it('sessão vencida no meio do caminho: entra e conclui com o código', async () => {
    let corpo: unknown = null;
    server.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json({ access_token: 'tok-novo', user: GERENTE }),
      ),
      http.get(`${API}/auth/me`, () => HttpResponse.json(GERENTE)),
      http.post(
        `${API}/integracoes/regem/clique/volta`,
        async ({ request }) => {
          corpo = await request.json();
          return HttpResponse.json({ situacao: 'recusado' });
        },
      ),
    );
    window.history.pushState(
      {},
      '',
      '/integracoes/regem/volta?code=c-9&state=s-9',
    );
    render(<App />);

    const email = (await waitFor(() => {
      const el = document.getElementById('email');
      if (!el) throw new Error('sem o formulário de entrar');
      return el;
    })) as HTMLInputElement;
    fireEvent.change(email, { target: { value: 'chefe@loja.com.br' } });
    fireEvent.change(document.getElementById('senha') as HTMLInputElement, {
      target: { value: 'senha-de-teste-1' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Entrar' }));

    expect(
      await screen.findByRole('heading', { name: 'Nada foi ligado' }),
    ).toBeInTheDocument();
    expect(corpo).toEqual({ code: 'c-9', state: 's-9' });
  });
});

describe('enderecoDoRegem', () => {
  it('aceita só https (e o Regem local de quem desenvolve)', () => {
    expect(
      enderecoDoRegem('https://app.dmsregem.com/integracoes/autorizar'),
    ).toBe(true);
    expect(enderecoDoRegem('http://localhost:3001/integracoes/autorizar')).toBe(
      true,
    );
    expect(enderecoDoRegem('http://app.dmsregem.com/x')).toBe(false);
    expect(enderecoDoRegem('javascript:alert(1)')).toBe(false);
    expect(enderecoDoRegem('/integracoes')).toBe(false);
    expect(enderecoDoRegem(undefined)).toBe(false);
  });
});
