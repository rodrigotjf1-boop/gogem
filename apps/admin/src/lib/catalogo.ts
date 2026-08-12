import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiDelete, apiGet, apiPatch, apiPost, apiPut } from '@/lib/api';
import { useSelectedCardapio } from '@/lib/cardapios';

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
  // Arte da categoria (roleta do totem): imagem ▸ emoji ▸ cor.
  imagemUrl: string | null;
  emoji: string | null;
  cor: string | null;
}

export interface Produto {
  id: string;
  nome: string;
  descricao: string | null;
  precoCentavos: number;
  disponivel: boolean;
  imagemUrl: string | null;
  selo: string | null;
  categoriaId: string | null;
  externalRefs: ExternalRef[];
}

export interface CategoriaInput {
  nome: string;
  ordem?: number;
  cardapioId?: string;
  imagemUrl?: string | null;
  emoji?: string | null;
  cor?: string | null;
}

export interface ProdutoInput {
  nome: string;
  descricao?: string;
  precoCentavos: number;
  disponivel?: boolean;
  imagemUrl?: string | null;
  selo?: string;
  categoriaId?: string;
  cardapioId?: string;
  externalRefs?: ExternalRef[];
}

/** Chaves de cache do react-query — incluem o cardápio para refetch ao trocar. */
export const catalogoKeys = {
  categorias: (cardapioId?: string | null) =>
    ['categorias', cardapioId ?? null] as const,
  produtos: (cardapioId?: string | null, categoriaId?: string) =>
    ['produtos', cardapioId ?? null, categoriaId ?? null] as const,
};

// ————————————————————————— Categorias —————————————————————————

export function useCategorias(): UseQueryResult<Categoria[]> {
  const { id: cardapioId } = useSelectedCardapio();
  return useQuery({
    queryKey: catalogoKeys.categorias(cardapioId),
    queryFn: () =>
      apiGet<Categoria[]>('/categorias', {
        params: cardapioId ? { cardapioId } : undefined,
      }),
    // Mantém a lista durante a troca de cardápio (sem flicker).
    placeholderData: keepPreviousData,
  });
}

export function useCriarCategoria() {
  const qc = useQueryClient();
  const { id: cardapioId } = useSelectedCardapio();
  return useMutation({
    mutationFn: (input: CategoriaInput) =>
      apiPost<Categoria, CategoriaInput>('/categorias', {
        ...input,
        cardapioId: cardapioId ?? undefined,
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['categorias'] }),
  });
}

export function useAtualizarCategoria() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: CategoriaInput }) =>
      apiPatch<Categoria, CategoriaInput>(`/categorias/${id}`, input),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['categorias'] }),
  });
}

export function useRemoverCategoria() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiDelete<{ id: string }>(`/categorias/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['categorias'] }),
  });
}

// ————————————————————————— Produtos —————————————————————————

export function useProdutos(categoriaId?: string): UseQueryResult<Produto[]> {
  const { id: cardapioId } = useSelectedCardapio();
  return useQuery({
    queryKey: catalogoKeys.produtos(cardapioId, categoriaId),
    queryFn: () => {
      const params: Record<string, string> = {};
      if (cardapioId) params.cardapioId = cardapioId;
      if (categoriaId) params.categoriaId = categoriaId;
      return apiGet<Produto[]>('/produtos', {
        params: Object.keys(params).length ? params : undefined,
      });
    },
    // Mantém a lista durante a troca de cardápio (sem flicker).
    placeholderData: keepPreviousData,
  });
}

/** Invalida TODAS as listas de produtos (qualquer cardápio/categoria). */
function invalidarProdutos(qc: ReturnType<typeof useQueryClient>) {
  return qc.invalidateQueries({ queryKey: ['produtos'] });
}

export function useCriarProduto() {
  const qc = useQueryClient();
  const { id: cardapioId } = useSelectedCardapio();
  return useMutation({
    mutationFn: (input: ProdutoInput) =>
      apiPost<Produto, ProdutoInput>('/produtos', {
        ...input,
        cardapioId: cardapioId ?? undefined,
      }),
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

/** Pausa/despausa o produto no totem (propaga ao Regem no servidor). */
export function usePausarProduto() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, pausado }: { id: string; pausado: boolean }) =>
      apiPost<{ propagadoRegem: boolean }, { pausado: boolean }>(
        `/produtos/${id}/pausa`,
        { pausado },
      ),
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

// ———————————————————— Complementos (grupos + opções) ————————————————————
// Espelha a árvore do Regem: produto → grupo (etapa) → opção. A OPÇÃO carrega
// o de-para PDV (`externalRefs`); opção SEM código PDV = "informativa".

export interface Opcao {
  id: string;
  grupoId: string;
  nome: string;
  precoCentavosDelta: number;
  disponivel: boolean;
  ordem: number;
  externalRefs: ExternalRef[];
}

export interface Grupo {
  id: string;
  produtoId: string;
  nome: string;
  min: number;
  max: number | null;
  obrigatorio: boolean;
  ordem: number;
  opcoes: Opcao[];
}

export interface GrupoInput {
  nome: string;
  min?: number;
  max?: number;
  obrigatorio?: boolean;
  ordem?: number;
}

export interface OpcaoInput {
  nome: string;
  precoCentavosDelta?: number;
  disponivel?: boolean;
  ordem?: number;
  externalRefs?: ExternalRef[];
}

/** Código PDV do Regem de uma opção (null = opção informativa). */
export function codigoPdvOpcao(opcao: Opcao): string | null {
  const ref = opcao.externalRefs?.find((r) => r.sistema === 'regem');
  return ref?.codigo_pdv ?? null;
}

export const complementoKeys = {
  grupos: (produtoId: string) => ['grupos', produtoId] as const,
};

export function useGrupos(
  produtoId: string,
  habilitado = true,
): UseQueryResult<Grupo[]> {
  return useQuery({
    queryKey: complementoKeys.grupos(produtoId),
    queryFn: () => apiGet<Grupo[]>(`/produtos/${produtoId}/grupos`),
    enabled: habilitado && Boolean(produtoId),
  });
}

function invalidarGrupos(
  qc: ReturnType<typeof useQueryClient>,
  produtoId: string,
) {
  return qc.invalidateQueries({ queryKey: complementoKeys.grupos(produtoId) });
}

export function useCriarGrupo(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: GrupoInput) =>
      apiPost<Grupo, GrupoInput>(`/produtos/${produtoId}/grupos`, input),
    onSuccess: () => invalidarGrupos(qc, produtoId),
  });
}

export function useAtualizarGrupo(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: GrupoInput }) =>
      apiPatch<Grupo, GrupoInput>(`/grupos/${id}`, input),
    onSuccess: () => invalidarGrupos(qc, produtoId),
  });
}

export function useRemoverGrupo(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiDelete<{ id: string }>(`/grupos/${id}`),
    onSuccess: () => invalidarGrupos(qc, produtoId),
  });
}

export function useCriarOpcao(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ grupoId, input }: { grupoId: string; input: OpcaoInput }) =>
      apiPost<Opcao, OpcaoInput>(`/grupos/${grupoId}/opcoes`, input),
    onSuccess: () => invalidarGrupos(qc, produtoId),
  });
}

export function useAtualizarOpcao(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: OpcaoInput }) =>
      apiPatch<Opcao, OpcaoInput>(`/opcoes/${id}`, input),
    onSuccess: () => invalidarGrupos(qc, produtoId),
  });
}

export function useRemoverOpcao(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiDelete<{ id: string }>(`/opcoes/${id}`),
    onSuccess: () => invalidarGrupos(qc, produtoId),
  });
}

// ————————————————— Upsell "Peça também" (F2) —————————————————

/** Uma sugestão de upsell configurada (com dados do produto sugerido). */
export interface Upsell {
  id: string;
  sugeridoId: string;
  nome: string;
  precoCentavos: number;
  imagemUrl: string | null;
  ordem: number;
}

export function useUpsells(produtoId: string): UseQueryResult<Upsell[]> {
  return useQuery({
    queryKey: ['upsells', produtoId],
    queryFn: () => apiGet<Upsell[]>(`/produtos/${produtoId}/upsells`),
  });
}

/** Substitui (replace-all) os upsells do produto na ordem enviada. */
export function useSalvarUpsells(produtoId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (sugeridoIds: string[]) =>
      apiPut<{ total: number }, { sugeridoIds: string[] }>(
        `/produtos/${produtoId}/upsells`,
        { sugeridoIds },
      ),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['upsells', produtoId] }),
  });
}
