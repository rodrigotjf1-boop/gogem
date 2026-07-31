import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiDelete, apiGet, apiPost } from '@/lib/api';

/** App parceiro do Open Delivery (gestão interna). */
export interface OdApp {
  id: string;
  nome: string;
  clientId: string;
  escopos: string[];
  ativo: boolean;
  ultimoUso: string | null;
  createdAt: string;
}

/** Retorno da criação — traz o clientSecret UMA vez. */
export interface OdAppCriado {
  id: string;
  nome: string;
  clientId: string;
  clientSecret: string;
  escopos: string[];
  ativo: boolean;
}

export const OD_ESCOPOS = [
  'catalog:read',
  'orders:read',
  'orders:write',
] as const;

const key = ['open-delivery-apps'] as const;

export function useOdApps(): UseQueryResult<OdApp[]> {
  return useQuery({
    queryKey: key,
    queryFn: () => apiGet<OdApp[]>('/open-delivery-apps'),
  });
}

export function useCriarOdApp() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: { nome: string; escopos?: string[] }) =>
      apiPost<OdAppCriado, { nome: string; escopos?: string[] }>(
        '/open-delivery-apps',
        input,
      ),
    onSuccess: () => qc.invalidateQueries({ queryKey: key }),
  });
}

export function useRevogarOdApp() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiDelete<{ id: string }>(`/open-delivery-apps/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: key }),
  });
}
