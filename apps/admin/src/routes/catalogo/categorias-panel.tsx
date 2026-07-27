import * as React from 'react';
import { Loader2, Pencil, Plus, Tags, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { usePodeEscrever } from '@/auth/auth-context';
import {
  useCategorias,
  useRemoverCategoria,
  type Categoria,
} from '@/lib/catalogo';
import { CategoriaDialog } from './categoria-dialog';

/** Lista + CRUD de categorias. Ações de escrita só aparecem para gerente+. */
export function CategoriasPanel() {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading, isError, refetch } = useCategorias();
  const remover = useRemoverCategoria();

  const [editando, setEditando] = React.useState<Categoria | undefined>();
  const [dialogAberto, setDialogAberto] = React.useState(false);
  const [removendo, setRemovendo] = React.useState<Categoria | undefined>();

  function abrirNova() {
    setEditando(undefined);
    setDialogAberto(true);
  }
  function abrirEdicao(c: Categoria) {
    setEditando(c);
    setDialogAberto(true);
  }

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          Organize os produtos por categoria. A ordem define a sequência no
          totem.
        </p>
        {podeEscrever && (
          <Button variant="primary" size="sm" onClick={abrirNova}>
            <Plus aria-hidden />
            Nova categoria
          </Button>
        )}
      </div>

      {isLoading && (
        <div
          className="flex items-center gap-2 py-10 text-sm text-muted-foreground"
          role="status"
        >
          <Loader2 className="size-4 animate-spin" aria-hidden />
          Carregando categorias…
        </div>
      )}

      {isError && (
        <div className="rounded-lg border border-border bg-card p-6 text-sm">
          <p className="text-destructive">Não foi possível carregar.</p>
          <Button
            variant="outline"
            size="sm"
            className="mt-3"
            onClick={() => refetch()}
          >
            Tentar novamente
          </Button>
        </div>
      )}

      {data && data.length === 0 && (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center">
          <div className="flex size-12 items-center justify-center rounded-full bg-secondary text-primary">
            <Tags className="size-5" aria-hidden />
          </div>
          <p className="font-display font-semibold">Nenhuma categoria ainda</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            Crie a primeira categoria para começar a montar o cardápio.
          </p>
          {podeEscrever && (
            <Button variant="primary" size="sm" onClick={abrirNova}>
              <Plus aria-hidden />
              Nova categoria
            </Button>
          )}
        </div>
      )}

      {data && data.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <caption className="sr-only">Categorias do catálogo</caption>
            <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Ordem</th>
                <th className="px-4 py-2 font-medium">Nome</th>
                {podeEscrever && (
                  <th className="px-4 py-2 text-right font-medium">Ações</th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data.map((c) => (
                <tr key={c.id} className="hover:bg-secondary/30">
                  <td className="px-4 py-2 font-mono text-muted-foreground">
                    {c.ordem}
                  </td>
                  <td className="px-4 py-2 font-medium">{c.nome}</td>
                  {podeEscrever && (
                    <td className="px-4 py-2">
                      <div className="flex justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          aria-label={`Editar ${c.nome}`}
                          onClick={() => abrirEdicao(c)}
                        >
                          <Pencil className="size-4" aria-hidden />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          aria-label={`Excluir ${c.nome}`}
                          onClick={() => setRemovendo(c)}
                        >
                          <Trash2 className="size-4 text-destructive" aria-hidden />
                        </Button>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <CategoriaDialog
        aberto={dialogAberto}
        onFechar={() => setDialogAberto(false)}
        categoria={editando}
      />

      <ConfirmDialog
        aberto={Boolean(removendo)}
        titulo="Excluir categoria"
        descricao={
          removendo
            ? `Excluir "${removendo.nome}"? Categorias com produtos vinculados não podem ser excluídas.`
            : ''
        }
        onConfirmar={async () => {
          if (removendo) await remover.mutateAsync(removendo.id);
        }}
        onFechar={() => setRemovendo(undefined)}
      />
    </section>
  );
}
