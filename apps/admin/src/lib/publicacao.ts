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
  const err = e as {
    response?: { status?: number; data?: { message?: string | string[] } };
    message?: string;
  };
  const msg = err?.response?.data?.message;
  if (Array.isArray(msg)) return msg.join(' ');
  if (typeof msg === 'string' && msg) return msg;
  // Sem `message` do servidor: dá o motivo real em vez de engolir num genérico
  // (ajuda a diagnosticar upload — 413 do proxy, 500 do storage, rede/CORS).
  const status = err?.response?.status;
  if (status === 413)
    return 'Arquivo grande demais para o servidor (limite do proxy). Use uma imagem menor.';
  if (status === 403) return 'Você não tem permissão para esta ação.';
  if (status && status >= 500)
    return `Erro no servidor (${status}). Verifique o storage de mídia (S3) da API.`;
  if (!err?.response)
    return 'Sem resposta do servidor (rede/CORS). Confira a conexão com a API.';
  return err?.message || 'Algo deu errado. Tente novamente.';
}
