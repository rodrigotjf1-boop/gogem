import {
  Download,
  GitCompareArrows,
  Loader2,
  PackageX,
  Sparkles,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { usePodeEscrever } from '@/auth/auth-context';
import { formatarBRL } from '@/lib/money';
import { usePausarProduto } from '@/lib/catalogo';
import {
  useIgnorarNovidade,
  useImportarRegem,
  useRegemConflitos,
  useRegemNovidades,
  useResolverConflito,
  type RegemConflito,
} from '@/lib/regem';

/** Valor legível de um conflito conforme o campo. */
function valorLegivel(campo: RegemConflito['campo'], v: string): string {
  if (campo === 'preco') return formatarBRL(Number(v) || 0);
  return v === 'true' ? 'Disponível' : 'Pausado';
}

/**
 * "Novidades do Regem" (Fase 2 do espelho): produtos novos no Regem sem par no
 * GoGeM (a importar) e produtos linkados que sumiram do Regem (órfãos, a pausar).
 * Só aparece quando a integração está configurada e há algo a mostrar.
 */
export function RegemNovidades() {
  const podeEscrever = usePodeEscrever();
  const { data, isError } = useRegemNovidades();
  const { data: conflitos } = useRegemConflitos();
  const importar = useImportarRegem();
  const ignorar = useIgnorarNovidade();
  const resolver = useResolverConflito();
  const pausar = usePausarProduto();

  // Integração não configurada / erro → não mostra nada.
  if (isError || !data) return null;
  const { novos, orfaos } = data;
  const listaConflitos = conflitos ?? [];
  if (
    novos.length === 0 &&
    orfaos.length === 0 &&
    listaConflitos.length === 0
  )
    return null;

  return (
    <Card className="space-y-4 border-primary/30 p-4">
      <h2 className="flex items-center gap-2 text-sm font-semibold">
        <Sparkles className="size-4 text-primary" aria-hidden />
        Espelho do Regem
      </h2>

      {listaConflitos.length > 0 && (
        <div className="space-y-2">
          <p className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
            <GitCompareArrows className="size-3.5 text-primary" aria-hidden />
            Conflitos ({listaConflitos.length}) — você gerencia este campo; o
            Regem mudou.
          </p>
          <ul className="divide-y divide-border rounded-md border border-border">
            {listaConflitos.map((c) => (
              <li key={c.id} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
                <span className="font-medium">{c.nome}</span>
                <span className="rounded bg-secondary px-1.5 py-0.5 text-xs">
                  {c.campo === 'preco' ? 'Preço' : 'Disponibilidade'}
                </span>
                <span className="text-xs text-muted-foreground">
                  Regem{' '}
                  <strong className="text-foreground">
                    {valorLegivel(c.campo, c.valorRegem)}
                  </strong>{' '}
                  × seu{' '}
                  <strong className="text-foreground">
                    {valorLegivel(c.campo, c.valorGogem)}
                  </strong>
                </span>
                {podeEscrever && (
                  <span className="ml-auto flex gap-1">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => resolver.mutate({ id: c.id, escolha: 'regem' })}
                      disabled={resolver.isPending}
                    >
                      Aceitar Regem
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => resolver.mutate({ id: c.id, escolha: 'gogem' })}
                      disabled={resolver.isPending}
                    >
                      Manter o meu
                    </Button>
                  </span>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}

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
