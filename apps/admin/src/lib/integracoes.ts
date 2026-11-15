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
  /** "Conectar pelo Regem" (só o Regem): `null` = o conector não tem o clique. */
  clique?: SituacaoClique | null;
}

/** A conexão pelo Regem: o presidente autoriza no Regem, loja por loja. Nunca leva a ligação. */
export interface SituacaoClique {
  /** O botão aparece: o servidor está configurado para o clique. */
  disponivel: boolean;
  conectado: boolean;
  emUso: { id: string; nome: string } | null;
  lojas: { id: string; nome: string }[];
  conectadoEm: string | null;
}

export type VoltaDoRegem =
  | { situacao: 'conectado'; clique: SituacaoClique; avisos: string }
  | { situacao: 'recusado' };

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

/** Só a página do Regem em https (ou o Regem local de quem desenvolve): nada de outro esquema. */
export function enderecoDoRegem(url: unknown): boolean {
  if (typeof url !== 'string') return false;
  try {
    const u = new URL(url);
    if (u.protocol === 'https:') return true;
    return (
      u.protocol === 'http:' &&
      (u.hostname === 'localhost' || u.hostname === '127.0.0.1')
    );
  } catch {
    return false;
  }
}

/** "Conectar pelo Regem": o servidor abre o pedido no Regem e devolve a página de lá. */
export function useConectarPeloRegem() {
  return useMutation({
    mutationFn: () => apiPost<{ url: string }>('/integracoes/regem/clique'),
  });
}

/** A volta do Regem: o que veio na barra de endereço, tal como veio. */
export function useConcluirClique() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (volta: {
      code?: string;
      state?: string;
      iss?: string;
      error?: string;
    }) =>
      apiPost<VoltaDoRegem, typeof volta>(
        '/integracoes/regem/clique/volta',
        volta,
      ),
    onSuccess: () => qc.invalidateQueries({ queryKey: integracoesKeys.all }),
  });
}

/** Troca a loja do Regem em uso (entre as que o presidente ligou). */
export function useEscolherLojaDoRegem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (lojaId: string) =>
      apiPost<SituacaoClique, { lojaId: string }>(
        '/integracoes/regem/clique/loja',
        { lojaId },
      ),
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
