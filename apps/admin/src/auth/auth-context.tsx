import * as React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { Loader2 } from 'lucide-react';
import { apiGet, apiPost } from '@/lib/api';
import {
  clearToken,
  getToken,
  setToken as persistToken,
} from '@/lib/auth-token';

/** Perfis de acesso do Regem/GoGeM (hierarquia decrescente). */
export type Papel = 'presidente' | 'gerente' | 'supervisao' | 'execucao';

/** Usuário autenticado — espelha exatamente o contrato de `/auth/*`. */
export interface AuthUser {
  id: string;
  tenantId: string;
  unidadeId: string | null;
  email: string;
  nome: string;
  papel: Papel;
}

/** Resposta comum de `POST /auth/login` e `POST /auth/register`. */
interface AuthResponse {
  access_token: string;
  user: AuthUser;
}

/** Payload de criação de conta/tenant. */
export interface RegisterInput {
  empresa: string;
  nome: string;
  email: string;
  senha: string;
}

/**
 * Ranking da hierarquia: presidente > gerente > supervisao > execucao.
 * Escrita (criar/editar/publicar) é permitida de **gerente para cima**.
 */
const PAPEL_RANK: Record<Papel, number> = {
  execucao: 0,
  supervisao: 1,
  gerente: 2,
  presidente: 3,
};

/**
 * Helper de RBAC puro: `true` quando o papel é **gerente ou acima**.
 * Exportado para o PR C reutilizar fora do provider (ex.: guards de rota,
 * botões de ação em tabelas do catálogo).
 */
// eslint-disable-next-line react-refresh/only-export-components
export function papelPodeEscrever(papel: Papel | null | undefined): boolean {
  if (!papel) return false;
  return PAPEL_RANK[papel] >= PAPEL_RANK.gerente;
}

interface AuthContextValue {
  user: AuthUser | null;
  isAuthenticated: boolean;
  /** `true` enquanto o boot (GET /auth/me) não resolveu — trava o RequireAuth. */
  carregando: boolean;
  /**
   * `true` quando o usuário logado pode escrever (papel gerente ou acima).
   * O front apenas oculta; a autorização real é sempre no servidor.
   */
  podeEscrever: boolean;
  /** Autentica por e-mail+senha. Lança em falha (mensagem genérica). */
  login: (email: string, senha: string) => Promise<void>;
  /** Cria conta/tenant e já deixa a sessão ativa. Lança em falha. */
  register: (input: RegisterInput) => Promise<void>;
  /** Encerra a sessão local. */
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
  // Só há boot a resolver se já existe um token persistido no arranque.
  const [carregando, setCarregando] = React.useState<boolean>(() =>
    Boolean(getToken()),
  );

  // Boot: com token persistido, valida a sessão em GET /auth/me.
  // Sucesso → popula o usuário; 401/erro → limpa e fica deslogado.
  // `carregando` permanece true até resolver, evitando flicker de redirect.
  React.useEffect(() => {
    if (!getToken()) {
      setCarregando(false);
      return;
    }
    let cancelado = false;
    apiGet<AuthUser>('/auth/me')
      .then((u) => {
        if (!cancelado) setUser(u);
      })
      .catch(() => {
        if (cancelado) return;
        clearToken();
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

  const aplicarSessao = React.useCallback((data: AuthResponse) => {
    persistToken(data.access_token);
    setTokenState(data.access_token);
    setUser(data.user);
  }, []);

  const login = React.useCallback(
    async (email: string, senha: string) => {
      try {
        const data = await apiPost<AuthResponse>('/auth/login', {
          email,
          senha,
        });
        aplicarSessao(data);
      } catch {
        // Mensagem genérica: nunca vazar se o e-mail existe.
        throw new Error('E-mail ou senha inválidos');
      }
    },
    [aplicarSessao],
  );

  const register = React.useCallback(
    async (input: RegisterInput) => {
      const data = await apiPost<AuthResponse>('/auth/register', input);
      aplicarSessao(data);
    },
    [aplicarSessao],
  );

  const logout = React.useCallback(() => {
    clearToken();
    setTokenState(null);
    setUser(null);
  }, []);

  const value = React.useMemo<AuthContextValue>(
    () => ({
      user,
      isAuthenticated: Boolean(token),
      carregando,
      podeEscrever: papelPodeEscrever(user?.papel),
      login,
      register,
      logout,
    }),
    [token, user, carregando, login, register, logout],
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

/**
 * Conveniência para o PR C: esconder/desabilitar ações de escrita.
 * Ex.: `const podeEscrever = usePodeEscrever();` e então
 * `{podeEscrever && <Button>Novo produto</Button>}`.
 */
// eslint-disable-next-line react-refresh/only-export-components
export function usePodeEscrever(): boolean {
  return useAuth().podeEscrever;
}

/**
 * Protege rotas privadas. Enquanto o boot não resolve (`carregando`), mostra
 * um loader — **não** redireciona, para não piscar /login numa sessão válida.
 * Depois: não autenticado → /login; autenticado → renderiza o conteúdo.
 */
export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, carregando } = useAuth();
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
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <>{children}</>;
}
