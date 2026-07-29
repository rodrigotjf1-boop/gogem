import * as React from 'react';
import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiDelete, apiGet, apiPatch, apiPost } from '@/lib/api';

/**
 * Cardápios (Fase 3B). Até 2 por loja, 1 ativo; o totem recebe SEMPRE o ativo.
 * O `SelectedCardapioContext` guarda qual cardápio o Catálogo está editando
 * (padrão: o ativo) — as telas de categoria/produto escopam por ele.
 */

export interface Cardapio {
  id: string;
  nome: string;
  ativo: boolean;
  ordem: number;
  produtos: number;
}

export interface CriarCardapioInput {
  nome: string;
  modo?: 'vazio' | 'duplicar';
}

export const cardapioKeys = {
  all: ['cardapios'] as const,
};

export function useCardapios(): UseQueryResult<Cardapio[]> {
  return useQuery({
    queryKey: cardapioKeys.all,
    queryFn: () => apiGet<Cardapio[]>('/cardapios'),
  });
}

function invalidarTudo(qc: ReturnType<typeof useQueryClient>) {
  qc.invalidateQueries({ queryKey: cardapioKeys.all });
  // Ativar/duplicar mudam o catálogo visível → invalida catálogo também.
  qc.invalidateQueries({ queryKey: ['produtos'] });
  qc.invalidateQueries({ queryKey: ['categorias'] });
}

export function useCriarCardapio() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: CriarCardapioInput) =>
      apiPost<Cardapio, CriarCardapioInput>('/cardapios', input),
    onSuccess: () => invalidarTudo(qc),
  });
}

export function useRenomearCardapio() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, nome }: { id: string; nome: string }) =>
      apiPatch<Cardapio, { nome: string }>(`/cardapios/${id}`, { nome }),
    onSuccess: () => invalidarTudo(qc),
  });
}

export function useAtivarCardapio() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiPost<Cardapio>(`/cardapios/${id}/ativar`),
    onSuccess: () => invalidarTudo(qc),
  });
}

export function useExcluirCardapio() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiDelete<{ id: string }>(`/cardapios/${id}`),
    onSuccess: () => invalidarTudo(qc),
  });
}

// ————————————— Contexto do cardápio selecionado (edição) —————————————

interface SelectedCardapioCtx {
  id: string | null;
  setId: (id: string | null) => void;
}

const SelectedCardapioContext = React.createContext<SelectedCardapioCtx>({
  id: null,
  setId: () => {},
});

export function SelectedCardapioProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [id, setId] = React.useState<string | null>(null);
  const { data } = useCardapios();

  // Default: o cardápio ativo, até o usuário escolher outro.
  React.useEffect(() => {
    if (id === null && data && data.length) {
      const ativo = data.find((c) => c.ativo) ?? data[0];
      setId(ativo.id);
    }
  }, [data, id]);

  const valor = React.useMemo(() => ({ id, setId }), [id]);
  return React.createElement(
    SelectedCardapioContext.Provider,
    { value: valor },
    children,
  );
}

/** Cardápio atualmente em edição (null = ainda carregando / usa o ativo). */
export function useSelectedCardapio(): SelectedCardapioCtx {
  return React.useContext(SelectedCardapioContext);
}
