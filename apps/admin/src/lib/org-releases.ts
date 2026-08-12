import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { orgGet, orgPost } from '@/lib/org-api';

/**
 * Releases do APK do totem (auto-update) — visão do Console da Distribuição.
 * A auth é a da ORGANIZAÇÃO (orgApi injeta o Bearer org); não há mais token
 * colado. O APK é GLOBAL (mesmo produto para todas as lojas).
 */
export interface KioskRelease {
  id: string;
  versionCode: number;
  versionName: string;
  apkUrl: string;
  sha256: string;
  notas: string | null;
  obrigatorio: boolean;
  ativo: boolean;
  createdAt: string;
}

export function useReleases(): UseQueryResult<KioskRelease[]> {
  return useQuery({
    queryKey: ['org-kiosk-releases'],
    queryFn: () => orgGet<KioskRelease[]>('/kiosk/releases'),
    retry: false,
  });
}

export interface PublicarReleaseInput {
  apk: File;
  versionCode: number;
  versionName: string;
  notas?: string;
  obrigatorio?: boolean;
}

export function usePublicarRelease() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: PublicarReleaseInput) => {
      const form = new FormData();
      form.append('apk', input.apk);
      form.append('versionCode', String(input.versionCode));
      form.append('versionName', input.versionName);
      if (input.notas) form.append('notas', input.notas);
      form.append('obrigatorio', input.obrigatorio ? 'true' : 'false');
      return orgPost<KioskRelease, FormData>('/kiosk/releases', form);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['org-kiosk-releases'] }),
  });
}
