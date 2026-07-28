import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiDelete, apiGet, apiPatch, apiPost } from '@/lib/api';

/**
 * Camada de dados do catálogo (categorias + produtos) sobre a API real.
 * Tipos espelham o contrato do backend (`apps/api`), incluindo o de-para PDV
 * (§4): `externalRefs[] { sistema, codigo_pdv, loja? }` em snake_case.
 * Preço sempre em centavos (inteiro).
 */

/** De-para PDV — chave da integração com o Regem é `codigo_pdv`. */
export interface ExternalRef {
  sistema: string;
  codigo_pdv: string;
  loja?: string;
}

export interface Categoria {
  id: string;
  nome: string;
  ordem: number;
}

export interface Produto {
  id: string;
  nome: string;
  descricao: string | null;
  precoCentavos: number;
  disponivel: boolean;
  imagemUrl: string | null;
  categoriaId: string | null;
  externalRefs: ExternalRef[];
}

export interface CategoriaInput {
  nome: string;
  ordem?: number;
}

export interface ProdutoInput {
  nome: string;
  descricao?: string;
  precoCentavos: number;
  disponivel?: boolean;
  imagemUrl?: string | null;
  categoriaId?: string;
  externalRefs?: ExternalRef[];
}

/** Chaves de cache do react-query — centralizadas para invalidação coerente. */
export const catalogoKeys = {
  categorias: ['categorias'] as const,
  produtos: (categoriaId?: string) => ['produtos', categoriaId ?? null] as const,
};

// ————————————————————————— Categorias —————————————————————————

export function useCategorias(): UseQueryResult<Categoria[]> {
  return useQuery({
    queryKey: catalogoKeys.categorias,
    queryFn: () => apiGet<Categoria[]>('/categorias'),
  });
}

export function useCriarCategoria() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: CategoriaInput) =>
      apiPost<Categoria, CategoriaInput>('/categorias', input),
    onSuccess: () => qc.invalidateQueries({ queryKey: catalogoKeys.categorias }),
  });
}

export function useAtualizarCategoria() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: CategoriaInput }) =>
      apiPatch<Categoria, CategoriaInput>(`/categorias/${id}`, input),
    onSuccess: () => qc.invalidateQueries({ queryKey: catalogoKeys.categorias }),
  });
}

export function useRemoverCategoria() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiDelete<{ id: string }>(`/categorias/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: catalogoKeys.categorias }),
  });
}

// ————————————————————————— Produtos —————————————————————————

export function useProdutos(categoriaId?: string): UseQueryResult<Produto[]> {
  return useQuery({
    queryKey: catalogoKeys.produtos(categoriaId),
    queryFn: () =>
      apiGet<Produto[]>('/produtos', {
        params: categoriaId ? { categoriaId } : undefined,
      }),
  });
}

/** Invalida TODAS as listas de produtos (qualquer filtro de categoria). */
function invalidarProdutos(qc: ReturnType<typeof useQueryClient>) {
  return qc.invalidateQueries({ queryKey: ['produtos'] });
}

export function useCriarProduto() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: ProdutoInput) =>
      apiPost<Produto, ProdutoInput>('/produtos', input),
    onSuccess: () => invalidarProdutos(qc),
  });
}

export function useAtualizarProduto() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: ProdutoInput }) =>
      apiPatch<Produto, ProdutoInput>(`/produtos/${id}`, input),
    onSuccess: () => invalidarProdutos(qc),
  });
}

export function useRemoverProduto() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiDelete<{ id: string }>(`/produtos/${id}`),
    onSuccess: () => invalidarProdutos(qc),
  });
}

/** Extrai o código PDV do Regem do de-para (o campo que a integração usa). */
export function codigoPdvRegem(produto: Produto): string | null {
  const ref = produto.externalRefs?.find((r) => r.sistema === 'regem');
  return ref?.codigo_pdv ?? null;
}

// ————————————————————————— Mídia (foto do produto) —————————————————————————

/**
 * Sobe uma imagem para o Storage e devolve a URL pública (POST /midia,
 * multipart `arquivo`). O caller guarda a URL em `imagemUrl` do produto.
 * O axios seta o boundary do multipart sozinho quando o body é FormData.
 */
export function useUploadImagem() {
  return useMutation({
    mutationFn: async (arquivo: File): Promise<string> => {
      const form = new FormData();
      form.append('arquivo', arquivo);
      const { url } = await apiPost<{ url: string }, FormData>('/midia', form);
      return url;
    },
  });
}
