import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPost } from '@/lib/api';

/**
 * Relatórios operacionais (Fase 7). Espelha o contrato do backend
 * (`/relatorios/*`, gerente+). Dinheiro sempre em centavos.
 */
export interface FaturamentoCard {
  totalCentavos: number;
  pedidos: number;
  ticketMedioCentavos: number;
}

export interface Resumo {
  hoje: FaturamentoCard;
  semana: FaturamentoCard;
  mesAtual: FaturamentoCard;
  mesAnterior: FaturamentoCard;
}

export type PedidoStatus = 'pendente' | 'enviado' | 'falha' | 'cancelado';

export interface PedidoRelatorio {
  id: string;
  criadoEm: string;
  dispositivo: string | null;
  cliente: string | null;
  cpf: string | null;
  senha: number | null;
  status: PedidoStatus;
  totalCentavos: number;
  formas: string[];
  itens: number;
  canceladoMotivo: string | null;
}

export interface ProdutoRanking {
  codigoPdv: string;
  nome: string;
  quantidade: number;
  pedidos: number;
}

/** Filtro de período (datas YYYY-MM-DD) + status opcional. */
export interface FiltroRelatorio {
  de: string;
  ate: string;
  status?: PedidoStatus;
}

/** Datas do input (dia) → limites ISO do intervalo (início e fim do dia). */
function intervalo(de: string, ate: string): { de: string; ate: string } {
  return { de: `${de}T00:00:00`, ate: `${ate}T23:59:59` };
}

export function useResumo(): UseQueryResult<Resumo> {
  return useQuery({
    queryKey: ['relatorios', 'resumo'],
    queryFn: () => apiGet<Resumo>('/relatorios/resumo'),
  });
}

export function usePedidos(f: FiltroRelatorio): UseQueryResult<PedidoRelatorio[]> {
  const { de, ate } = intervalo(f.de, f.ate);
  return useQuery({
    queryKey: ['relatorios', 'pedidos', f.de, f.ate, f.status ?? 'todos'],
    queryFn: () =>
      apiGet<PedidoRelatorio[]>('/relatorios/pedidos', {
        params: { de, ate, ...(f.status ? { status: f.status } : {}) },
      }),
  });
}

export function useProdutos(
  f: Pick<FiltroRelatorio, 'de' | 'ate'>,
): UseQueryResult<ProdutoRanking[]> {
  const { de, ate } = intervalo(f.de, f.ate);
  return useQuery({
    queryKey: ['relatorios', 'produtos', f.de, f.ate],
    queryFn: () =>
      apiGet<ProdutoRanking[]>('/relatorios/produtos', { params: { de, ate } }),
  });
}

export function useCancelarPedido() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (v: { id: string; motivo: string }) =>
      apiPost<{ id: string }, { motivo: string }>(
        `/relatorios/pedidos/${v.id}/cancelar`,
        { motivo: v.motivo },
      ),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['relatorios'], exact: false }),
  });
}
