import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import { apiGet, apiPost } from '@/lib/api';

/**
 * Releases do APK do totem (auto-update). Publicar é ação do DMS (o APK é o
 * produto, igual para todas as lojas), então vai por um token de sistema
 * (X-Release-Token = KIOSK_RELEASE_TOKEN da API), guardado no navegador do dono.
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

const RELEASE_TOKEN_KEY = 'gogem.releaseToken';

export function getReleaseToken(): string {
  try {
    return localStorage.getItem(RELEASE_TOKEN_KEY) ?? '';
  } catch {
    return '';
  }
}

export function setReleaseToken(token: string): void {
  try {
    localStorage.setItem(RELEASE_TOKEN_KEY, token);
  } catch {
    /* ignore */
  }
}

export function useReleases(token: string): UseQueryResult<KioskRelease[]> {
  return useQuery({
    queryKey: ['kiosk-releases', token],
    queryFn: () =>
      apiGet<KioskRelease[]>('/kiosk/releases', {
        headers: { 'X-Release-Token': token },
      }),
    enabled: token.length > 0,
    retry: false,
  });
}

export interface PublicarReleaseInput {
  apk: File;
  versionCode: number;
  versionName: string;
  notas?: string;
  obrigatorio?: boolean;
  token: string;
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
      return apiPost<KioskRelease, FormData>('/kiosk/releases', form, {
        headers: { 'X-Release-Token': input.token },
      });
    },
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['kiosk-releases'] }),
  });
}
