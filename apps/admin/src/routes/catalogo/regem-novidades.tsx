import { Download, Loader2, PackageX, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { usePodeEscrever } from '@/auth/auth-context';
import { formatarBRL } from '@/lib/money';
import { usePausarProduto } from '@/lib/catalogo';
import {
  useIgnorarNovidade,
  useImportarRegem,
  useRegemNovidades,
} from '@/lib/regem';

/**
 * "Novidades do Regem" (Fase 2 do espelho): produtos novos no Regem sem par no
 * GoGeM (a importar) e produtos linkados que sumiram do Regem (órfãos, a pausar).
 * Só aparece quando a integração está configurada e há algo a mostrar.
 */
export function RegemNovidades() {
  const podeEscrever = usePodeEscrever();
  const { data, isError } = useRegemNovidades();
  const importar = useImportarRegem();
  const ignorar = useIgnorarNovidade();
  const pausar = usePausarProduto();

  // Integração não configurada / erro → não mostra nada.
  if (isError || !data) return null;
  const { novos, orfaos } = data;
  if (novos.length === 0 && orfaos.length === 0) return null;

  return (
    <Card className="space-y-4 border-primary/30 p-4">
      <h2 className="flex items-center gap-2 text-sm font-semibold">
        <Sparkles className="size-4 text-primary" aria-hidden />
        Novidades do Regem
      </h2>

      {novos.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center justify-between gap-2">
            <p className="text-xs font-medium text-muted-foreground">
              Novos no Regem ({novos.length}) — importe para organizar categoria
              e foto.
            </p>
            {podeEscrever && (
              <Button
                variant="primary"
                size="sm"
                onClick={() => importar.mutate()}
                disabled={importar.isPending}
              >
                {importar.isPending ? (
                  <Loader2 className="size-4 animate-spin" aria-hidden />
                ) : (
                  <Download className="size-4" aria-hidden />
                )}
                Importar todas
              </Button>
            )}
          </div>
          <ul className="divide-y divide-border rounded-md border border-border">
            {novos.map((n) => (
              <li
                key={n.codigo}
                className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm"
              >
                <span className="font-medium">{n.nome}</span>
                <span className="font-mono text-xs text-muted-foreground">
                  {n.codigo}
                </span>
                <span className="font-mono">{formatarBRL(n.precoCentavos)}</span>
                {podeEscrever && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="ml-auto"
                    onClick={() => ignorar.mutate(n.codigo)}
                    disabled={ignorar.isPending}
                  >
                    Ignorar
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}

      {orfaos.length > 0 && (
        <div className="space-y-2">
          <p className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
            <PackageX className="size-3.5 text-destructive" aria-hidden />
            Sumiram do Regem ({orfaos.length}) — pause para tirar do totem.
          </p>
          <ul className="divide-y divide-border rounded-md border border-border">
            {orfaos.map((o) => (
              <li
                key={o.id}
                className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm"
              >
                <span className="font-medium">{o.nome}</span>
                <span className="font-mono text-xs text-muted-foreground">
                  {o.codigo}
                </span>
                {podeEscrever && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="ml-auto"
                    onClick={() => pausar.mutate({ id: o.id, pausado: true })}
                    disabled={pausar.isPending}
                  >
                    Pausar
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </Card>
  );
}
