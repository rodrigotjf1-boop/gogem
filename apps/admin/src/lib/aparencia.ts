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
  temaPreset: 'padrao' | 'brasa';
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
