import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import App from '@/App';
import { server } from '@/test/msw/server';
import { clearToken, getToken, setToken } from '@/lib/auth-token';

// Mesma resolução do cliente axios (api.ts): respeita VITE_API_URL do ambiente.
const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

const USER = {
  id: 'u1',
  tenantId: 't1',
  unidadeId: 'un1',
  email: 'ana@loja.com.br',
  nome: 'Ana Silva',
  papel: 'gerente' as const,
};

function irPara(path: string) {
  window.history.pushState({}, '', path);
}

function preencher(labelId: string, valor: string) {
  const campo = document.getElementById(labelId) as HTMLInputElement;
  fireEvent.change(campo, { target: { value: valor } });
}

beforeEach(() => {
  clearToken();
});

describe('Login', () => {
  it('sucesso: guarda o token e navega para /catalogo', async () => {
    server.use(
      http.post(`${API}/auth/login`, async () => {
        return HttpResponse.json({ access_token: 'tok-123', user: USER });
      }),
    );

    irPara('/login');
    render(<App />);

    preencher('email', 'ana@loja.com.br');
    preencher('senha', 'segredo123');
    fireEvent.click(screen.getByRole('button', { name: 'Entrar' }));

    await waitFor(() => {
      expect(
        screen.getByRole('heading', { name: 'Catálogo' }),
      ).toBeInTheDocument();
    });
    expect(getToken()).toBe('tok-123');
  });

  it('401: mostra mensagem genérica e não guarda token', async () => {
    server.use(
      http.post(`${API}/auth/login`, () => {
        return HttpResponse.json({ message: 'Unauthorized' }, { status: 401 });
      }),
    );

    irPara('/login');
    render(<App />);

    preencher('email', 'ana@loja.com.br');
    preencher('senha', 'senhaerrada');
    fireEvent.click(screen.getByRole('button', { name: 'Entrar' }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(
        'E-mail ou senha inválidos',
      );
    });
    expect(getToken()).toBeNull();
  });

  it('valida com zod antes de chamar a API', async () => {
    irPara('/login');
    render(<App />);

    preencher('email', 'nao-e-email');
    preencher('senha', '123');
    fireEvent.click(screen.getByRole('button', { name: 'Entrar' }));

    expect(
      await screen.findByText('Informe um e-mail válido'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('A senha deve ter ao menos 6 caracteres'),
    ).toBeInTheDocument();
    expect(getToken()).toBeNull();
  });
});

describe('Registro', () => {
  it('sucesso: cria conta, guarda token e navega para /catalogo', async () => {
    server.use(
      http.post(`${API}/auth/register`, async () => {
        return HttpResponse.json({ access_token: 'tok-reg', user: USER });
      }),
    );

    irPara('/registro');
    render(<App />);

    preencher('empresa', 'Minha Loja');
    preencher('nome', 'Ana Silva');
    preencher('email', 'ana@loja.com.br');
    preencher('senha', 'segredo123');
    fireEvent.click(screen.getByRole('button', { name: 'Criar conta' }));

    await waitFor(() => {
      expect(
        screen.getByRole('heading', { name: 'Catálogo' }),
      ).toBeInTheDocument();
    });
    expect(getToken()).toBe('tok-reg');
  });
});

describe('Boot da sessão', () => {
  it('com token válido: GET /auth/me restaura a sessão', async () => {
    setToken('tok-existente');
    server.use(
      http.get(`${API}/auth/me`, () => HttpResponse.json(USER)),
    );

    irPara('/catalogo');
    render(<App />);

    // Enquanto resolve, mostra o loader (não redireciona).
    expect(screen.getByRole('status')).toBeInTheDocument();

    await waitFor(() => {
      expect(
        screen.getByRole('heading', { name: 'Catálogo' }),
      ).toBeInTheDocument();
    });
    // Nome do usuário aparece na topbar.
    expect(screen.getByText('Ana Silva')).toBeInTheDocument();
  });

  it('token inválido: 401 no /auth/me desloga e vai para /login', async () => {
    setToken('tok-invalido');
    // A 401 no boot também dispara o redirect global do interceptor
    // (window.location.assign) — no jsdom é um no-op inofensivo; quem de fato
    // leva ao /login aqui é o RequireAuth ao ficar deslogado.
    server.use(
      http.get(`${API}/auth/me`, () =>
        HttpResponse.json({ message: 'Unauthorized' }, { status: 401 }),
      ),
    );

    irPara('/catalogo');
    render(<App />);

    await waitFor(() => {
      expect(
        screen.getByRole('heading', { name: 'Entrar' }),
      ).toBeInTheDocument();
    });
    expect(getToken()).toBeNull();
  });
});

describe('Logout', () => {
  it('limpa o token e retorna ao /login', async () => {
    setToken('tok-existente');
    server.use(
      http.get(`${API}/auth/me`, () => HttpResponse.json(USER)),
    );

    irPara('/catalogo');
    render(<App />);

    await waitFor(() => {
      expect(
        screen.getByRole('heading', { name: 'Catálogo' }),
      ).toBeInTheDocument();
    });

    fireEvent.click(screen.getByRole('button', { name: 'Sair' }));

    await waitFor(() => {
      expect(
        screen.getByRole('heading', { name: 'Entrar' }),
      ).toBeInTheDocument();
    });
    expect(getToken()).toBeNull();
  });
});
