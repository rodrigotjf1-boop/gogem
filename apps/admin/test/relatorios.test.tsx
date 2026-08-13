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

const RESUMO = {
  hoje: { totalCentavos: 5000, pedidos: 2, ticketMedioCentavos: 2500 },
  semana: { totalCentavos: 12000, pedidos: 5, ticketMedioCentavos: 2400 },
  mesAtual: { totalCentavos: 30000, pedidos: 12, ticketMedioCentavos: 2500 },
  mesAnterior: { totalCentavos: 20000, pedidos: 8, ticketMedioCentavos: 2500 },
};

const PEDIDOS = [
  {
    id: 'p1',
    criadoEm: '2026-07-10T14:30:00.000Z',
    dispositivo: 'Totem entrada',
    cliente: 'Ana',
    cpf: null,
    senha: 42,
    status: 'enviado',
    totalCentavos: 2990,
    formas: ['cartao'],
    itens: 2,
    canceladoMotivo: null,
  },
];

const PRODUTOS = [
  { codigoPdv: 'A', nome: 'X-Burger', quantidade: 10, pedidos: 6 },
  { codigoPdv: 'B', nome: 'Batata', quantidade: 4, pedidos: 4 },
];

function baseHandlers() {
  server.use(
    http.get(`${API}/relatorios/resumo`, () => HttpResponse.json(RESUMO)),
    http.get(`${API}/relatorios/pedidos`, () => HttpResponse.json(PEDIDOS)),
    http.get(`${API}/relatorios/produtos`, () => HttpResponse.json(PRODUTOS)),
  );
}

function montar(papel: 'presidente' | 'gerente' | 'execucao' = 'gerente') {
  setToken('tok');
  server.use(http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))));
  window.history.pushState({}, '', '/relatorios');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Relatórios', () => {
  it('mostra os cards de faturamento e a variação vs mês anterior', async () => {
    baseHandlers();
    montar('gerente');

    // Ancora nos cards do resumo por um texto que só existe neles (o preset
    // "Hoje" também renderiza um botão com esse texto).
    expect(await screen.findByText('Mês atual')).toBeInTheDocument();
    expect(screen.getByText('Últimos 7 dias')).toBeInTheDocument();
    // 30000 vs 20000 = +50%
    expect(await screen.findByText(/50% vs mês anterior/)).toBeInTheDocument();
  });

  it('lista pedidos com totem, cliente e forma de pagamento', async () => {
    baseHandlers();
    montar('gerente');

    expect(await screen.findByText('Totem entrada')).toBeInTheDocument();
    expect(screen.getByText('Ana')).toBeInTheDocument();
    expect(screen.getByText('cartao')).toBeInTheDocument();
    // "Enviado" também é uma opção do filtro; o badge está na tabela.
    expect(within(screen.getByRole('table')).getByText('Enviado')).toBeInTheDocument();
  });

  it('troca para o ranking de produtos', async () => {
    baseHandlers();
    montar('gerente');

    fireEvent.click(await screen.findByRole('tab', { name: 'Ranking de produtos' }));
    expect(await screen.findByText('X-Burger')).toBeInTheDocument();
    expect(screen.getByText('Batata')).toBeInTheDocument();
  });

  it('cancela um pedido enviado com motivo', async () => {
    baseHandlers();
    let cancelado: { id: string; motivo: string } | null = null;
    server.use(
      http.post(`${API}/relatorios/pedidos/:id/cancelar`, async ({ request, params }) => {
        const body = (await request.json()) as { motivo: string };
        cancelado = { id: String(params.id), motivo: body.motivo };
        return HttpResponse.json({ id: String(params.id) });
      }),
    );
    montar('gerente');

    fireEvent.click(await screen.findByRole('button', { name: /Cancelar pedido/ }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.click(within(dialog).getByRole('button', { name: 'Confirmar cancelamento' }));

    await screen.findByText('Totem entrada'); // re-render após invalidação
    expect(cancelado).toEqual({ id: 'p1', motivo: 'Falta de saldo' });
  });

  it('execução (somente leitura) não vê ação de cancelar', async () => {
    baseHandlers();
    montar('execucao');

    expect(await screen.findByText('Totem entrada')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: /Cancelar pedido/ }),
    ).not.toBeInTheDocument();
  });
});
