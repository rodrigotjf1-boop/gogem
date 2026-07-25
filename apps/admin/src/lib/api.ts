import axios, {
  type AxiosInstance,
  type AxiosRequestConfig,
  type InternalAxiosRequestConfig,
} from 'axios';
import { clearToken, getToken } from './auth-token';

/**
 * Cliente HTTP central do backoffice.
 * - baseURL vem de VITE_API_URL (ex.: http://localhost:3000/api/v1).
 * - Request interceptor injeta `Authorization: Bearer <token>`.
 * - Response interceptor: em 401 limpa o token e redireciona para /login.
 */
const baseURL =
  import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

export const api: AxiosInstance = axios.create({
  baseURL,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = getToken();
  if (token) {
    config.headers.set('Authorization', `Bearer ${token}`);
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error?.response?.status;
    if (status === 401) {
      clearToken();
      // Evita loop caso já estejamos na tela de login.
      if (
        typeof window !== 'undefined' &&
        !window.location.pathname.startsWith('/login')
      ) {
        window.location.assign('/login');
      }
    }
    return Promise.reject(error);
  },
);

/** Helpers tipados finos sobre o axios. */
export async function apiGet<T>(
  url: string,
  config?: AxiosRequestConfig,
): Promise<T> {
  const { data } = await api.get<T>(url, config);
  return data;
}

export async function apiPost<T, B = unknown>(
  url: string,
  body?: B,
  config?: AxiosRequestConfig,
): Promise<T> {
  const { data } = await api.post<T>(url, body, config);
  return data;
}

export async function apiPut<T, B = unknown>(
  url: string,
  body?: B,
  config?: AxiosRequestConfig,
): Promise<T> {
  const { data } = await api.put<T>(url, body, config);
  return data;
}

export async function apiDelete<T>(
  url: string,
  config?: AxiosRequestConfig,
): Promise<T> {
  const { data } = await api.delete<T>(url, config);
  return data;
}
