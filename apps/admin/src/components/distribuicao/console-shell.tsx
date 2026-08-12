import { NavLink, Outlet } from 'react-router-dom';
import { LayoutDashboard, LogOut, PackageCheck, Activity } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { useOrgAuth } from '@/auth/org-auth-context';

/**
 * Shell do Console da Distribuição (organização/DMS) — layout PRÓPRIO, separado
 * do admin do cliente. Sidebar da distribuição + topbar com logout. As seções
 * Versões e Telemetria chegam nas fatias 2 e 3 (por ora, rotas placeholder).
 */
const NAV_ITEMS = [
  { to: '/distribuicao', label: 'Visão geral', icon: LayoutDashboard, end: true },
  { to: '/distribuicao/versoes', label: 'Versões', icon: PackageCheck, end: false },
  {
    to: '/distribuicao/telemetria',
    label: 'Telemetria',
    icon: Activity,
    end: false,
  },
] as const;

export function ConsoleShell() {
  const { user, logout } = useOrgAuth();
  return (
    <div className="flex min-h-screen bg-background text-foreground">
      <aside className="hidden w-60 shrink-0 flex-col border-r border-border bg-sidebar text-sidebar-foreground md:flex">
        <div className="flex h-14 items-center gap-2 border-b border-border px-5">
          <span className="font-display text-lg font-semibold">GoGeM</span>
          <span className="rounded bg-secondary px-1.5 py-0.5 font-sans text-[10px] font-medium uppercase tracking-wide text-muted-foreground">
            Distribuição
          </span>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto p-3" aria-label="Distribuição">
          {NAV_ITEMS.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-secondary text-primary'
                    : 'text-sidebar-foreground/80 hover:bg-secondary/60 hover:text-sidebar-foreground',
                )
              }
            >
              <Icon className="size-4 shrink-0" aria-hidden />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-border p-4 text-xs text-muted-foreground">
          DMS · organização
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-14 shrink-0 items-center justify-between gap-3 border-b border-border px-5">
          <span className="text-sm text-muted-foreground">
            Console da Distribuição
          </span>
          <div className="flex items-center gap-3">
            <span className="hidden text-sm text-muted-foreground sm:inline">
              {user?.nome ?? user?.email}
            </span>
            <Button variant="outline" size="sm" onClick={logout}>
              <LogOut className="size-4" aria-hidden />
              Sair
            </Button>
          </div>
        </header>
        <main className="min-w-0 flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
