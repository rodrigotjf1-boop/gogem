import * as React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { Loader2 } from 'lucide-react';
import { orgGet, orgPost } from '@/lib/org-api';
import {
  clearOrgToken,
  getOrgToken,
  setOrgToken as persistOrgToken,
} from '@/lib/org-token';

/** Usuário da organização (DMS) — espelha `/org/*`. */
export interface OrgUser {
  id: string;
  email: string;
  nome: string;
  papel: string;
  ativo: boolean;
}

interface OrgAuthResponse {
  access_token: string;
  user: OrgUser;
}

interface OrgAuthContextValue {
  user: OrgUser | null;
  isAuthenticated: boolean;
  carregando: boolean;
  login: (email: string, senha: string) => Promise<void>;
  logout: () => void;
}

const OrgAuthContext = React.createContext<OrgAuthContextValue | undefined>(
  undefined,
);

/**
 * OrgAuthProvider — sessão do Console da Distribuição, TOTALMENTE separada da
 * sessão do cliente (token e contexto próprios). Boot em `GET /org/me`.
 */
export function OrgAuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setTokenState] = React.useState<string | null>(() =>
    getOrgToken(),
  );
  const [user, setUser] = React.useState<OrgUser | null>(null);
  const [carregando, setCarregando] = React.useState<boolean>(() =>
    Boolean(getOrgToken()),
  );

  React.useEffect(() => {
    if (!getOrgToken()) {
      setCarregando(false);
      return;
    }
    let cancelado = false;
    orgGet<OrgUser>('/org/me')
      .then((u) => {
        if (!cancelado) setUser(u);
      })
      .catch(() => {
        if (cancelado) return;
        clearOrgToken();
        setTokenState(null);
        setUser(null);
      })
      .finally(() => {
        if (!cancelado) setCarregando(false);
      });
    return () => {
      cancelado = true;
    };
  }, []);

  const login = React.useCallback(async (email: string, senha: string) => {
    try {
      const data = await orgPost<OrgAuthResponse>('/org/auth/login', {
        email,
        senha,
      });
      persistOrgToken(data.access_token);
      setTokenState(data.access_token);
      setUser(data.user);
    } catch {
      throw new Error('E-mail ou senha inválidos');
    }
  }, []);

  const logout = React.useCallback(() => {
    clearOrgToken();
    setTokenState(null);
    setUser(null);
  }, []);

  const value = React.useMemo<OrgAuthContextValue>(
    () => ({
      user,
      isAuthenticated: Boolean(token),
      carregando,
      login,
      logout,
    }),
    [token, user, carregando, login, logout],
  );

  return (
    <OrgAuthContext.Provider value={value}>{children}</OrgAuthContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useOrgAuth(): OrgAuthContextValue {
  const ctx = React.useContext(OrgAuthContext);
  if (!ctx) {
    throw new Error('useOrgAuth deve ser usado dentro de <OrgAuthProvider>.');
  }
  return ctx;
}

/** Protege as rotas do console: sem sessão org → /distribuicao/login. */
export function RequireOrgAuth({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, carregando } = useOrgAuth();
  const location = useLocation();

  if (carregando) {
    return (
      <div
        className="flex min-h-screen items-center justify-center bg-background"
        role="status"
        aria-live="polite"
      >
        <Loader2 className="size-6 animate-spin text-primary" aria-hidden />
        <span className="sr-only">Carregando sessão…</span>
      </div>
    );
  }
  if (!isAuthenticated) {
    return (
      <Navigate to="/distribuicao/login" state={{ from: location }} replace />
    );
  }
  return <>{children}</>;
}
