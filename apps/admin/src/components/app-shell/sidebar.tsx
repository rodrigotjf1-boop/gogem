import { NavLink } from 'react-router-dom';
import { BookOpen, Download, Radio, UploadCloud } from 'lucide-react';
import { cn } from '@/lib/utils';
import { GogemMark } from '@/components/brand/gogem-mark';

const NAV_ITEMS = [
  { to: '/catalogo', label: 'Catálogo', icon: BookOpen },
  { to: '/importar', label: 'Importar', icon: Download },
  { to: '/publicar', label: 'Publicar', icon: UploadCloud },
  { to: '/frota', label: 'Auto atendimentos', icon: Radio },
] as const;

export function Sidebar() {
  return (
    <aside className="hidden w-60 shrink-0 flex-col border-r border-border bg-sidebar text-sidebar-foreground md:flex">
      <div className="flex h-14 items-center gap-2 border-b border-border px-5">
        <GogemMark />
        <span className="rounded bg-secondary px-1.5 py-0.5 font-sans text-[10px] font-medium uppercase tracking-wide text-muted-foreground">
          Admin
        </span>
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto p-3" aria-label="Principal">
        {NAV_ITEMS.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
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
        GoGeM by DMS
      </div>
    </aside>
  );
}
