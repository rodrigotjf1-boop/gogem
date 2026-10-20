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
  tipo?: 'texto' | 'toggle';
  preenchido: boolean;
  valor: string;
}

export interface TesteResultado {
  ok: boolean;
  detalhe: string;
  em: string;
}

/** Avisos assinados que o sistema externo manda ao GoGeM (o Regem, hoje). */
export interface SituacaoAvisos {
  ligados: boolean;
  registradoEm: string | null;
  erro: string | null;
  detalhe: string;
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
  /** `null` = o conector não tem avisos assinados. */
  avisos?: SituacaoAvisos | null;
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

/** Desliga os avisos assinados (o Regem volta ao caminho antigo); religar = "Testar conexão". */
export function useDesligarAvisos() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (tipo: string) =>
      apiPost<SituacaoAvisos>(`/integracoes/${tipo}/avisos/desligar`),
    onSuccess: () => qc.invalidateQueries({ queryKey: integracoesKeys.all }),
  });
}

export function useImportarConector() {
  return useMutation({
    mutationFn: ({ tipo, cardapioId }: { tipo: string; cardapioId?: string }) =>
      apiPost<ImportResumo>(`/integracoes/${tipo}/importar`, undefined, {
        params: cardapioId ? { cardapioId } : undefined,
      }),
  });
}
