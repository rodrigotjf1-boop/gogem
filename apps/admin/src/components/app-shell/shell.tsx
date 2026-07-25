import { Outlet } from 'react-router-dom';
import { LogOut } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { GogemMark } from '@/components/brand/gogem-mark';
import { useAuth } from '@/auth/auth-context';
import { Sidebar } from './sidebar';

/**
 * Layout autenticado: sidebar fixa + topbar fixa; o conteúdo (<Outlet/>)
 * é a única região que rola. Viewport travado (h-screen + overflow-hidden).
 */
export function Shell() {
  const { user, logout } = useAuth();

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-14 shrink-0 items-center justify-between gap-4 border-b border-border bg-card px-4 md:px-6">
          <div className="flex items-center gap-3 md:hidden">
            <GogemMark />
          </div>

          <div className="ml-auto flex items-center gap-3">
            <span className="hidden text-sm text-muted-foreground sm:inline">
              {user?.nome ?? 'Sessão'}
            </span>
            <Button
              variant="ghost"
              size="sm"
              onClick={logout}
              aria-label="Sair"
            >
              <LogOut className="size-4" aria-hidden />
              <span className="hidden sm:inline">Sair</span>
            </Button>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-4 md:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
