import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPost } from '@/lib/api';

/**
 * Camada de dados da Frota (dispositivos/totens) sobre a API real. Espelha o
 * DispositivoService: criar emite um código de pareamento de 6 dígitos (uso
 * único, 15 min); o totem troca esse código por um token de dispositivo.
 * O token NUNCA volta ao admin (segredo do dispositivo).
 */

/** Estado reportado pelo totem no heartbeat (Json flexível). */
export interface DispositivoStatus {
  versaoCatalogo?: number;
  filaImpressao?: number;
  impressoraOk?: boolean;
  papelAcabando?: boolean;
  appVersao?: string;
}

export interface Dispositivo {
  id: string;
  unidadeId: string | null;
  nome: string;
  tipo: string;
  pareado: boolean;
  codigoPareamento: string | null;
  codigoExpiraEm: string | null;
  ativo: boolean;
  ultimoHeartbeat: string | null;
  ultimoStatus: DispositivoStatus | null;
  createdAt: string;
  updatedAt: string;
}

/** Online = heartbeat recente (< 2 min). */
export function estaOnline(ultimoHeartbeat: string | null): boolean {
  if (!ultimoHeartbeat) return false;
  return Date.now() - new Date(ultimoHeartbeat).getTime() < 2 * 60_000;
}

/** Resposta ao criar/reparear: o código aparece UMA vez. */
export interface CodigoEmitido {
  id: string;
  nome: string;
  codigoPareamento: string;
  codigoExpiraEm: string;
}

export interface CriarDispositivoInput {
  nome: string;
  tipo?: string;
  unidadeId?: string;
}

export const frotaKeys = {
  dispositivos: ['dispositivos'] as const,
};

export function useDispositivos(): UseQueryResult<Dispositivo[]> {
  return useQuery({
    queryKey: frotaKeys.dispositivos,
    queryFn: () => apiGet<Dispositivo[]>('/dispositivos'),
    // o código expira em 15 min; recarrega sozinho de tempos em tempos.
    refetchInterval: 30_000,
  });
}

function invalidar(qc: ReturnType<typeof useQueryClient>) {
  return qc.invalidateQueries({ queryKey: frotaKeys.dispositivos });
}

export function useCriarDispositivo() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: CriarDispositivoInput) =>
      apiPost<CodigoEmitido, CriarDispositivoInput>('/dispositivos', input),
    onSuccess: () => invalidar(qc),
  });
}

export function useRevogar() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiPost<Dispositivo>(`/dispositivos/${id}/revogar`),
    onSuccess: () => invalidar(qc),
  });
}

export function useReparear() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiPost<CodigoEmitido>(`/dispositivos/${id}/reparear`),
    onSuccess: () => invalidar(qc),
  });
}

/** Um código expirou? (compara com agora). */
export function codigoExpirado(codigoExpiraEm: string | null): boolean {
  if (!codigoExpiraEm) return true;
  return new Date(codigoExpiraEm).getTime() < Date.now();
}
