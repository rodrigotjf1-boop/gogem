import { beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import App from '@/App';
import { server } from '@/test/msw/server';
import { clearToken, setToken } from '@/lib/auth-token';
import { queryClient } from '@/lib/query';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

const APARENCIA = {
  id: 'ap-1',
  // O GET devolve o registro inteiro — inclui campos que o DTO de update
  // rejeita (whitelist). O patch NÃO pode reenviá-los.
  tenantId: 't1',
  createdAt: '2026-07-01T00:00:00.000Z',
  updatedAt: '2026-07-01T00:00:00.000Z',
  corPrimaria: '#FFC24B',
  corDestaque: '#3ECF8E',
  corFundo: '#0F1713',
  corPainel: '#16211B',
  raio: 16,
  nomeLoja: 'MISTER BURGERS',
  logoUrl: null,
  fonteDisplay: 'Tektur',
  temaPreset: 'brasa',
  descansoTipo: 'padrao',
  descansoIntervaloSeg: 6,
  descansoMidias: [],
  chamada: 'TOQUE PARA PEDIR',
  precoIsca: null,
  estiloCard: 'cheia',
  animacoes: 'cheio',
};

function usuario(papel: 'gerente' | 'execucao') {
  return { id: 'u1', tenantId: 't1', unidadeId: null, email: 'c@l', nome: 'C', papel };
}

function montar(
  papel: 'gerente' | 'execucao' = 'gerente',
  aparencia: Record<string, unknown> = APARENCIA,
) {
  setToken('tok');
  server.use(
    http.get(`${API}/auth/me`, () => HttpResponse.json(usuario(papel))),
    http.get(`${API}/aparencia`, () => HttpResponse.json(aparencia)),
  );
  window.history.pushState({}, '', '/configuracoes');
  render(<App />);
}

beforeEach(() => {
  clearToken();
  queryClient.clear();
});

describe('Configurações · Aparência', () => {
  it('carrega e salva a aparência (envia o patch com a cor alterada)', async () => {
    let recebido: Record<string, unknown> | null = null;
    montar('gerente');
    server.use(
      http.put(`${API}/aparencia`, async ({ request }) => {
        recebido = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ ...APARENCIA, ...recebido });
      }),
    );

    const nome = await screen.findByLabelText('Nome da loja');
    expect((nome as HTMLInputElement).value).toBe('MISTER BURGERS');

    fireEvent.change(nome, { target: { value: 'BURGER TOP' } });
    fireEvent.click(screen.getByRole('button', { name: 'Salvar aparência' }));

    await waitFor(() => expect(recebido).not.toBeNull());
    expect(recebido!.nomeLoja).toBe('BURGER TOP');
    // Só campos editáveis: nada de id/tenantId/createdAt/updatedAt (whitelist).
    expect('id' in recebido!).toBe(false);
    expect('tenantId' in recebido!).toBe(false);
    expect('createdAt' in recebido!).toBe(false);
    expect('updatedAt' in recebido!).toBe(false);
    expect(await screen.findByText('Aparência salva.')).toBeInTheDocument();
  });

  it('mostra as mídias do carrossel só quando tipo = carrossel', async () => {
    montar('gerente');
    // padrão: não mostra o editor de mídias
    await screen.findByLabelText('Nome da loja');
    expect(screen.queryByText('Mídias do carrossel')).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Tipo'), {
      target: { value: 'carrossel' },
    });
    expect(await screen.findByText('Mídias do carrossel')).toBeInTheDocument();
  });

  it('estilo do totem: só Brasa e GoGen — Padrão e Burger House saíram da lista', async () => {
    montar('gerente');
    await screen.findByLabelText('Nome da loja');
    const estilo = screen.getByLabelText('Estilo do totem') as HTMLSelectElement;
    const opcoes = [...estilo.options].map((o) => o.textContent);
    expect(opcoes).toEqual(['Brasa (steakhouse)', 'GoGen (roleta / flame)']);
    expect(estilo.value).toBe('brasa');
  });

  it('loja ainda no Burger House vê o estilo dela (até a migração), não um select vazio', async () => {
    montar('gerente', { ...APARENCIA, temaPreset: 'burger' });
    await screen.findByLabelText('Nome da loja');
    const estilo = screen.getByLabelText('Estilo do totem') as HTMLSelectElement;
    expect(estilo.value).toBe('burger');
    expect([...estilo.options].map((o) => o.value)).toEqual(['brasa', 'gogen', 'burger']);
  });

  it('execução não vê o botão de salvar', async () => {
    montar('execucao');
    await screen.findByLabelText('Nome da loja');
    expect(
      screen.queryByRole('button', { name: 'Salvar aparência' }),
    ).not.toBeInTheDocument();
  });
});
