import { Card, CardContent } from '@/components/ui/card';

/** Placeholder das seções da Distribuição que chegam nas fatias 2 e 3. */
export default function EmBreve({ titulo }: { titulo: string }) {
  return (
    <div className="mx-auto max-w-4xl space-y-4">
      <h1 className="font-display text-2xl font-semibold">{titulo}</h1>
      <Card>
        <CardContent className="py-10 text-center text-sm text-muted-foreground">
          Em breve — esta seção chega na próxima fatia da Distribuição.
        </CardContent>
      </Card>
    </div>
  );
}
