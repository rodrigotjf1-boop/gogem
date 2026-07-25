import type { LucideIcon } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

interface PagePlaceholderProps {
  title: string;
  description: string;
  icon: LucideIcon;
  /** Sprint em que a tela recebe conteúdo real (rótulo informativo). */
  sprint?: string;
}

/** Cabeçalho de página + estado vazio "em construção" (scaffold do PR A). */
export function PagePlaceholder({
  title,
  description,
  icon: Icon,
  sprint,
}: PagePlaceholderProps) {
  return (
    <section className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">{title}</h1>
        <p className="text-sm text-muted-foreground">{description}</p>
      </header>

      <Card>
        <CardContent className="flex flex-col items-center gap-3 py-16 text-center">
          <div className="flex size-14 items-center justify-center rounded-full bg-secondary text-primary">
            <Icon className="size-6" aria-hidden />
          </div>
          <p className="font-display text-lg font-semibold">Em construção</p>
          <p className="max-w-md text-sm text-muted-foreground">
            Esta tela ainda é um esqueleto. A funcionalidade completa chega em
            um PR seguinte{sprint ? ` (${sprint})` : ''}.
          </p>
        </CardContent>
      </Card>
    </section>
  );
}
