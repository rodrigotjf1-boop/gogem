import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
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

const regem = (avisos: unknown) => ({
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
  avisos,
});

const LIGADOS = {
  ligados: true,
  registradoEm: '2026-10-20T03:00:00.000Z',
  erro: null,
  detalhe: 'Avisos do Regem: ligados (assinados).',
};

function montar(papel: 'gerente' | 'execucao', avisos: unknown) {
  setToken('tok');
  server.use(
    http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))),
    http.get(`${API}/integracoes`, () => HttpResponse.json([regem(avisos)])),
    http.get(`${API}/cardapios`, () => HttpResponse.json([])),
  );
  window.history.pushState({}, '', '/integracoes');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});
afterEach(() => {
  vi.restoreAllMocks();
});

describe('Integrações — avisos assinados do Regem', () => {
  it('mostra os avisos ligados e desliga, depois de confirmar', async () => {
    let chamou = 0;
    server.use(
      http.post(`${API}/integracoes/regem/avisos/desligar`, () => {
        chamou += 1;
        return HttpResponse.json({
          ligados: false,
          registradoEm: null,
          erro: null,
          detalhe:
            'Avisos do Regem desligados: o Regem voltou ao caminho antigo.',
        });
      }),
    );
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    montar('gerente', LIGADOS);

    expect(
      await screen.findByText('Avisos do Regem: ligados (assinados).'),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Desligar avisos' }));

    expect(
      await screen.findByText(
        'Avisos do Regem desligados: o Regem voltou ao caminho antigo.',
      ),
    ).toBeInTheDocument();
    expect(chamou).toBe(1);
  });

  it('sem confirmar, não desliga', async () => {
    let chamou = 0;
    server.use(
      http.post(`${API}/integracoes/regem/avisos/desligar`, () => {
        chamou += 1;
        return HttpResponse.json(LIGADOS);
      }),
    );
    vi.spyOn(window, 'confirm').mockReturnValue(false);
    montar('gerente', LIGADOS);

    fireEvent.click(
      await screen.findByRole('button', { name: 'Desligar avisos' }),
    );
    expect(chamou).toBe(0);
  });

  it('quem só lê vê a situação, mas não o botão', async () => {
    montar('execucao', LIGADOS);
    expect(
      await screen.findByText('Avisos do Regem: ligados (assinados).'),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Desligar avisos' }),
    ).toBeNull();
  });

  it('avisos nunca ligados (caminho antigo) não aparecem no cartão', async () => {
    montar('gerente', {
      ligados: false,
      registradoEm: null,
      erro: null,
      detalhe:
        'Avisos do Regem: não ligados (o Regem avisa pelo caminho antigo).',
    });
    expect(await screen.findByText('Regem')).toBeInTheDocument();
    expect(screen.queryByText(/Avisos do Regem/)).toBeNull();
  });
});
