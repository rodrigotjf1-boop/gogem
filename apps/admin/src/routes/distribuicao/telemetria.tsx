import { Loader2 } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { mensagemDeErro } from '@/lib/publicacao';
import { useEventos, type TelemetriaEvento } from '@/lib/org-telemetria';

/**
 * Telemetria — Console da Distribuição. Erros/avisos de TODA a frota (cross-
 * tenant), pra acompanhar bugs. Os totens sobem via /telemetria/evento.
 */
export default function TelemetriaPage() {
  const eventos = useEventos();
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <div>
        <h1 className="font-display text-2xl font-semibold">Telemetria</h1>
        <p className="text-sm text-muted-foreground">
          Erros e avisos dos totens de todas as lojas (mais recentes primeiro).
          Atualiza sozinho a cada 30s.
        </p>
      </div>

      <Card>
        <CardContent className="p-0">
          {eventos.isLoading ? (
            <div className="flex items-center gap-2 p-6 text-sm text-muted-foreground">
              <Loader2 className="size-4 animate-spin" aria-hidden /> Carregando…
            </div>
          ) : eventos.isError ? (
            <p className="p-6 text-sm text-destructive">
              {mensagemDeErro(eventos.error)}
            </p>
          ) : !eventos.data?.length ? (
            <p className="p-6 text-sm text-muted-foreground">
              Nenhum evento ainda.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <caption className="sr-only">Eventos de telemetria</caption>
                <thead className="border-b border-border text-left text-xs text-muted-foreground">
                  <tr>
                    <th className="px-4 py-2 font-medium">Quando</th>
                    <th className="px-4 py-2 font-medium">Nível</th>
                    <th className="px-4 py-2 font-medium">Loja</th>
                    <th className="px-4 py-2 font-medium">Totem</th>
                    <th className="px-4 py-2 font-medium">Mensagem</th>
                  </tr>
                </thead>
                <tbody>
                  {eventos.data.map((e) => (
                    <LinhaEvento key={e.id} e={e} />
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function LinhaEvento({ e }: { e: TelemetriaEvento }) {
  const cor =
    e.nivel === 'erro'
      ? 'bg-destructive/10 text-destructive'
      : e.nivel === 'aviso'
        ? 'bg-amber-500/10 text-amber-600'
        : 'bg-secondary text-muted-foreground';
  return (
    <tr className="border-b border-border/60 align-top">
      <td className="whitespace-nowrap px-4 py-2 text-xs text-muted-foreground">
        {new Date(e.createdAt).toLocaleString('pt-BR')}
      </td>
      <td className="px-4 py-2">
        <span className={`rounded px-1.5 py-0.5 text-xs ${cor}`}>{e.nivel}</span>
      </td>
      <td className="px-4 py-2">{e.loja}</td>
      <td className="px-4 py-2">
        {e.dispositivo}
        {e.appVersao && (
          <span className="ml-1 font-mono text-xs text-muted-foreground">
            {e.appVersao}
          </span>
        )}
      </td>
      <td className="px-4 py-2">
        <div>{e.mensagem}</div>
        {e.detalhe && (
          <details className="mt-1">
            <summary className="cursor-pointer text-xs text-muted-foreground">
              detalhe
            </summary>
            <pre className="mt-1 max-h-40 overflow-auto whitespace-pre-wrap rounded bg-secondary/50 p-2 text-xs">
              {e.detalhe}
            </pre>
          </details>
        )}
      </td>
    </tr>
  );
}
