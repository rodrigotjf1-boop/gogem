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
