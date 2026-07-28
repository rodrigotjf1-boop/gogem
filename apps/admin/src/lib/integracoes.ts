import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPost, apiPut } from '@/lib/api';
import type { ImportResumo } from '@/lib/publicacao';

/**
 * Camada de dados das Integrações (Fase 2). Espelha o contrato de
 * `/integracoes` do backend. Segredos NUNCA chegam crus: campos-segredo vêm
 * mascarados (`valor` = máscara quando `preenchido`).
 */

export interface IntegracaoCampo {
  key: string;
  label: string;
  secret: boolean;
  url?: boolean;
  ajuda?: string;
  preenchido: boolean;
  valor: string;
}

export interface TesteResultado {
  ok: boolean;
  detalhe: string;
  em: string;
}

export interface Integracao {
  tipo: string;
  nome: string;
  descricao: string;
  disponivel: boolean;
  importaCatalogo: boolean;
  ativo: boolean;
  configurado: boolean;
  campos: IntegracaoCampo[];
  nomePersonalizado: string | null;
  ultimoTeste: TesteResultado | null;
}

export interface SalvarIntegracaoInput {
  nome?: string;
  ativo?: boolean;
  config?: Record<string, string>;
}

export const integracoesKeys = {
  all: ['integracoes'] as const,
};

export function useIntegracoes(): UseQueryResult<Integracao[]> {
  return useQuery({
    queryKey: integracoesKeys.all,
    queryFn: () => apiGet<Integracao[]>('/integracoes'),
  });
}

export function useSalvarIntegracao() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      tipo,
      input,
    }: {
      tipo: string;
      input: SalvarIntegracaoInput;
    }) => apiPut<Integracao, SalvarIntegracaoInput>(`/integracoes/${tipo}`, input),
    onSuccess: () => qc.invalidateQueries({ queryKey: integracoesKeys.all }),
  });
}

export function useTestarIntegracao() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (tipo: string) =>
      apiPost<TesteResultado>(`/integracoes/${tipo}/testar`),
    onSuccess: () => qc.invalidateQueries({ queryKey: integracoesKeys.all }),
  });
}

export function useImportarConector() {
  return useMutation({
    mutationFn: (tipo: string) =>
      apiPost<ImportResumo>(`/integracoes/${tipo}/importar`),
  });
}
