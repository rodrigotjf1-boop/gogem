import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPost } from '@/lib/api';

/**
 * Camada de dados de importação (Regem) e publicação versionada do catálogo,
 * sobre a API real (`apps/api`). Espelha os contratos de
 * `RegemImportService` e `CatalogoPublicacaoService`.
 */

/** Resumo do import do Regem (`POST /import/regem`). */
export interface ImportResumo {
  geradoEm: string;
  categorias: { criadas: number; atualizadas: number };
  produtos: { criados: number; atualizados: number; ignoradosSemCodigo: number };
  grupos: { criados: number; atualizados: number };
  opcoes: { criados: number; atualizados: number };
}

/** Resultado de publicar (`POST /catalogo/publicar`). */
export interface PublicarResultado {
  versao: number;
  publishedAt: string;
  totais: {
    categorias: number;
    produtos: number;
    grupos: number;
    opcoes: number;
  };
}

/** Metadados de uma versão publicada (`GET /catalogo/versoes`). */
export interface VersaoMeta {
  id: string;
  versao: number;
  publishedAt: string;
  publishedById: string | null;
}

export const publicacaoKeys = {
  versoes: ['catalogo', 'versoes'] as const,
};

export function useImportarRegem() {
  return useMutation({
    mutationFn: () => apiPost<ImportResumo>('/import/regem'),
  });
}

export function useVersoes(): UseQueryResult<VersaoMeta[]> {
  return useQuery({
    queryKey: publicacaoKeys.versoes,
    queryFn: () => apiGet<VersaoMeta[]>('/catalogo/versoes'),
  });
}

export function usePublicar() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => apiPost<PublicarResultado>('/catalogo/publicar'),
    onSuccess: () => qc.invalidateQueries({ queryKey: publicacaoKeys.versoes }),
  });
}

/** Extrai a mensagem de erro da API (ex.: 400 Regem não configurado). */
export function mensagemDeErro(e: unknown): string {
  const msg = (e as { response?: { data?: { message?: string | string[] } } })
    ?.response?.data?.message;
  if (Array.isArray(msg)) return msg.join(' ');
  if (typeof msg === 'string') return msg;
  return 'Algo deu errado. Tente novamente.';
}
