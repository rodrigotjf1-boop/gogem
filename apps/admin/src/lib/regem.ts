import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPost } from '@/lib/api';

/** Diferenças Regem×GoGeM (Fase 2 do espelho). */
export interface RegemNovo {
  codigo: string;
  nome: string;
  precoCentavos: number;
}
export interface RegemOrfao {
  id: string;
  nome: string;
  codigo: string;
}
export interface RegemNovidades {
  novos: RegemNovo[];
  orfaos: RegemOrfao[];
}

export function useRegemNovidades(): UseQueryResult<RegemNovidades> {
  return useQuery({
    queryKey: ['regem', 'novidades'],
    queryFn: () => apiGet<RegemNovidades>('/import/regem/novidades'),
    // Integração não configurada / offline → não fica retentando nem polui a UI.
    retry: false,
  });
}

export function useIgnorarNovidade() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (codigo: string) =>
      apiPost<{ ignorados: string[] }, { codigo: string }>(
        '/import/regem/ignorar',
        { codigo },
      ),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['regem', 'novidades'] }),
  });
}

export function useImportarRegem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () =>
      apiPost<unknown, Record<string, never>>('/import/regem', {}),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['regem', 'novidades'] });
      qc.invalidateQueries({ queryKey: ['categorias'] });
      qc.invalidateQueries({ queryKey: ['produtos'] });
    },
  });
}

/** Conflito do espelho (loja é a fonte e o Regem diverge). */
export interface RegemConflito {
  id: string;
  produtoId: string;
  nome: string;
  codigo: string;
  campo: 'preco' | 'disponivel';
  valorRegem: string;
  valorGogem: string;
}

export function useRegemConflitos(): UseQueryResult<RegemConflito[]> {
  return useQuery({
    queryKey: ['regem', 'conflitos'],
    queryFn: () => apiGet<RegemConflito[]>('/import/regem/conflitos'),
    retry: false,
  });
}

export function useResolverConflito() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (v: { id: string; escolha: 'regem' | 'gogem' }) =>
      apiPost<{ id: string }, { escolha: 'regem' | 'gogem' }>(
        `/import/regem/conflitos/${v.id}/resolver`,
        { escolha: v.escolha },
      ),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['regem', 'conflitos'] });
      qc.invalidateQueries({ queryKey: ['produtos'] });
    },
  });
}
