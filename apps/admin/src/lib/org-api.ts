import axios, {
  type AxiosInstance,
  type AxiosRequestConfig,
  type InternalAxiosRequestConfig,
} from 'axios';
import { clearOrgToken, getOrgToken } from './org-token';

/**
 * Cliente HTTP do **Console da Distribuição** (organização). Instância axios
 * PRÓPRIA: injeta o token ORG (`gogem.org.token`), e em 401 limpa e volta pra
 * `/distribuicao/login` (não pro /login do cliente). Mesma baseURL da API.
 */
const baseURL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

export const orgApi: AxiosInstance = axios.create({
  baseURL,
  headers: { 'Content-Type': 'application/json' },
});

orgApi.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = getOrgToken();
  if (token) config.headers.set('Authorization', `Bearer ${token}`);
  if (typeof FormData !== 'undefined' && config.data instanceof FormData) {
    config.headers.delete('Content-Type');
  }
  return config;
});

orgApi.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error?.response?.status === 401) {
      clearOrgToken();
      if (
        typeof window !== 'undefined' &&
        !window.location.pathname.startsWith('/distribuicao/login')
      ) {
        window.location.assign('/distribuicao/login');
      }
    }
    return Promise.reject(error);
  },
);

export async function orgGet<T>(
  url: string,
  config?: AxiosRequestConfig,
): Promise<T> {
  const { data } = await orgApi.get<T>(url, config);
  return data;
}

export async function orgPost<T, B = unknown>(
  url: string,
  body?: B,
  config?: AxiosRequestConfig,
): Promise<T> {
  const { data } = await orgApi.post<T>(url, body, config);
  return data;
}
