import { useQuery, type UseQueryResult } from '@tanstack/react-query';
import { orgGet } from '@/lib/org-api';

/** Evento de telemetria de um totem, como o Console vê (cross-tenant). */
export interface TelemetriaEvento {
  id: string;
  nivel: string;
  mensagem: string;
  detalhe: string | null;
  appVersao: string | null;
  createdAt: string;
  dispositivo: string;
  loja: string;
}

/** Eventos recentes de toda a frota (org). Auto-refetch a cada 30s. */
export function useEventos(): UseQueryResult<TelemetriaEvento[]> {
  return useQuery({
    queryKey: ['org-telemetria-eventos'],
    queryFn: () => orgGet<TelemetriaEvento[]>('/org/telemetria/eventos'),
    refetchInterval: 30_000,
    retry: false,
  });
}
