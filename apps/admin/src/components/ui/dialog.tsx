import * as React from 'react';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

/**
 * Modal acessível mínimo (sem dependência de UI pesada — CLAUDE.md do kiosk
 * vale de espírito aqui: nada de libs grandes sem necessidade).
 *
 * - `role="dialog"` + `aria-modal` + rótulo via `titulo`.
 * - Fecha com Escape e clique no backdrop.
 * - Trava o scroll do body enquanto aberto.
 * - Foco inicial no container (o formulário interno assume a partir daí).
 */
interface DialogProps {
  aberto: boolean;
  onFechar: () => void;
  titulo: string;
  descricao?: string;
  children: React.ReactNode;
  /** Largura máxima (classe Tailwind). Padrão: max-w-lg. */
  larguraClasse?: string;
}

export function Dialog({
  aberto,
  onFechar,
  titulo,
  descricao,
  children,
  larguraClasse = 'max-w-lg',
}: DialogProps) {
  const painelRef = React.useRef<HTMLDivElement>(null);
  const tituloId = React.useId();
  const descricaoId = React.useId();

  React.useEffect(() => {
    if (!aberto) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onFechar();
    }
    document.addEventListener('keydown', onKey);
    const overflowAntes = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    // Foco inicial no painel para leitores de tela e navegação por teclado.
    painelRef.current?.focus();
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = overflowAntes;
    };
  }, [aberto, onFechar]);

  if (!aberto) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-0 sm:items-center sm:p-4"
      onMouseDown={(e) => {
        // Fecha só quando o clique começa no backdrop (não ao arrastar de dentro).
        if (e.target === e.currentTarget) onFechar();
      }}
    >
      <div
        ref={painelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={tituloId}
        aria-describedby={descricao ? descricaoId : undefined}
        tabIndex={-1}
        className={cn(
          'max-h-[90vh] w-full overflow-y-auto rounded-t-lg border border-border bg-card text-card-foreground shadow-lg outline-none sm:rounded-lg',
          larguraClasse,
        )}
      >
        <div className="flex items-start justify-between gap-4 border-b border-border p-4 sm:p-6">
          <div className="space-y-1">
            <h2
              id={tituloId}
              className="font-display text-lg font-semibold leading-none tracking-tight"
            >
              {titulo}
            </h2>
            {descricao && (
              <p id={descricaoId} className="text-sm text-muted-foreground">
                {descricao}
              </p>
            )}
          </div>
          <button
            type="button"
            onClick={onFechar}
            aria-label="Fechar"
            className="rounded-md p-1 text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            <X className="size-5" aria-hidden />
          </button>
        </div>
        <div className="p-4 sm:p-6">{children}</div>
      </div>
    </div>
  );
}
