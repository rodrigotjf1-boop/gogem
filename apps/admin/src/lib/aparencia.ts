import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPut } from '@/lib/api';

/**
 * Aparência do totem (Fase 6) — por loja. O totem consome no
 * `/catalogo/publicado` e aplica no próximo sync. Espelha o contrato do backend.
 */
export interface DescansoMidia {
  url: string;
  tipo?: 'imagem' | 'gif' | 'video';
  /** Legendas do slide (F3) — opcionais. */
  kicker?: string;
  titulo?: string;
  subtitulo?: string;
}

export interface Aparencia {
  id: string;
  corPrimaria: string;
  corDestaque: string;
  corFundo: string;
  corPainel: string;
  raio: number;
  nomeLoja: string | null;
  logoUrl: string | null;
  fonteDisplay: 'Tektur' | 'Poppins' | 'Montserrat';
  /**
   * Estilo do totem. 'burger' só existe até a migração das lojas para o Brasa 2.0;
   * 'padrao' saiu (as lojas nele foram para o GoGen).
   */
  temaPreset:
    | 'brasa'
    | 'gogen'
    | 'burger'
    | 'brasa2'
    | 'vitrine'
    | 'estudio'
    | 'neon'
    | 'diner';
  descansoTipo: 'padrao' | 'carrossel';
  descansoIntervaloSeg: number;
  descansoMidias: DescansoMidia[];
  chamada: string;
  precoIsca: string | null;
  estiloCard: 'cheia' | 'lateral';
  animacoes: 'cheio' | 'reduzido' | 'off';
}

export type AparenciaInput = Partial<Omit<Aparencia, 'id'>>;

const aparenciaKey = ['aparencia'] as const;

export function useAparencia(): UseQueryResult<Aparencia> {
  return useQuery({
    queryKey: aparenciaKey,
    queryFn: () => apiGet<Aparencia>('/aparencia'),
  });
}

export function useSalvarAparencia() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: AparenciaInput) =>
      apiPut<Aparencia, AparenciaInput>('/aparencia', input),
    onSuccess: (data) => qc.setQueryData(aparenciaKey, data),
  });
}

/**
 * Estilos do totem na ordem da lista (docs/templates). Cada template novo entra aqui no
 * PR em que o app do totem passa a desenhá-lo.
 */
export const ESTILOS_TOTEM: Aparencia['temaPreset'][] = ['brasa', 'gogen', 'brasa2'];

export const ROTULO_ESTILO: Record<string, string> = {
  brasa: 'Brasa (steakhouse)',
  gogen: 'GoGen (roleta / flame)',
  burger: 'Burger House (hambúrguer) — sai da lista',
  brasa2: 'Brasa 2.0 (steakhouse com fogo)',
  vitrine: 'Vitrine (cardápio em stories)',
  estudio: 'Estúdio (clean, produtos flutuando)',
  neon: 'Neon 2.0 (noite urbana)',
  diner: 'Diner 58 (lanchonete anos 50)',
};

/**
 * A lista do select: os estilos disponíveis e, se a loja ainda estiver num estilo que saiu
 * da lista (Burger House, até a migração), ele também — senão o select ficaria em branco.
 */
export function estilosDoTotem(atual: string): string[] {
  return ESTILOS_TOTEM.includes(atual as Aparencia['temaPreset'])
    ? [...ESTILOS_TOTEM]
    : [...ESTILOS_TOTEM, atual];
}
