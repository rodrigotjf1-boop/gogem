import { cn } from '@/lib/utils';

/**
 * Wordmark GoGeM em Tektur (display). Assets definitivos (logotipo/monograma)
 * são follow-up de branding — ver docs/roadmap §1. Por ora, apenas o texto
 * com a grafia oficial (G e M maiúsculos) e o "G" central em âmbar.
 */
export function GogemMark({ className }: { className?: string }) {
  return (
    <span
      className={cn(
        'font-display text-xl font-bold tracking-tight text-foreground',
        className,
      )}
      aria-label="GoGeM"
    >
      Go<span className="text-primary">G</span>eM
    </span>
  );
}
