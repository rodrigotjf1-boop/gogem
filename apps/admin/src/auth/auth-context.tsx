import * as React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import {
  clearToken,
  getToken,
  setToken as persistToken,
} from '@/lib/auth-token';

export interface AuthUser {
  id: string;
  nome: string;
  email: string;
  tenantId: string;
  role: string;
}

interface AuthContextValue {
  token: string | null;
  user: AuthUser | null;
  isAuthenticated: boolean;
  /**
   * STUB — no PR B isto chama a API de login. Por ora apenas persiste o
   * token/usuário recebidos para exercitar a proteção de rotas.
   */
  login: (token: string, user?: AuthUser) => void;
  logout: () => void;
}

const AuthContext = React.createContext<AuthContextValue | undefined>(
  undefined,
);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setTokenState] = React.useState<string | null>(() =>
    getToken(),
  );
  const [user, setUser] = React.useState<AuthUser | null>(null);

  const login = React.useCallback((newToken: string, newUser?: AuthUser) => {
    persistToken(newToken);
    setTokenState(newToken);
    if (newUser) setUser(newUser);
  }, []);

  const logout = React.useCallback(() => {
    clearToken();
    setTokenState(null);
    setUser(null);
  }, []);

  const value = React.useMemo<AuthContextValue>(
    () => ({
      token,
      user,
      isAuthenticated: Boolean(token),
      login,
      logout,
    }),
    [token, user, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthContextValue {
  const ctx = React.useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth deve ser usado dentro de <AuthProvider>.');
  }
  return ctx;
}

/** Protege rotas privadas: redireciona para /login quando não autenticado. */
export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <>{children}</>;
}
