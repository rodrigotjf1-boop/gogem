import * as React from 'react';
import {
  ImageOff,
  ListTree,
  Loader2,
  Package,
  Pause,
  Pencil,
  Play,
  Plus,
  Trash2,
} from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { usePodeEscrever } from '@/auth/auth-context';
import { formatarBRL } from '@/lib/money';
import {
  codigoPdvRegem,
  useCategorias,
  usePausarProduto,
  useProdutos,
  useRemoverProduto,
  type Produto,
} from '@/lib/catalogo';
import { ProdutoDialog } from './produto-dialog';
import { ComplementosDialog } from './complementos-dialog';

/** Lista + CRUD de produtos, com filtro por categoria e de-para PDV visível. */
export function ProdutosPanel() {
  const podeEscrever = usePodeEscrever();
  const [filtroCategoria, setFiltroCategoria] = React.useState('');
  const categoriasQuery = useCategorias();
  const { data, isLoading, isError, refetch } = useProdutos(
    filtroCategoria || undefined,
  );
  const remover = useRemoverProduto();
  const pausar = usePausarProduto();

  const categoriasData = categoriasQuery.data;
  const categorias = React.useMemo(
    () => categoriasData ?? [],
    [categoriasData],
  );
  const nomeCategoria = React.useCallback(
    (id: string | null) =>
      id ? (categorias.find((c) => c.id === id)?.nome ?? '—') : '—',
    [categorias],
  );

  const [editando, setEditando] = React.useState<Produto | undefined>();
  const [dialogAberto, setDialogAberto] = React.useState(false);
  const [removendo, setRemovendo] = React.useState<Produto | undefined>();
  const [complementosDe, setComplementosDe] = React.useState<
    Produto | undefined
  >();

  function abrirNovo() {
    setEditando(undefined);
    setDialogAberto(true);
  }
  function abrirEdicao(p: Produto) {
    setEditando(p);
    setDialogAberto(true);
  }

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <label
            htmlFor="filtro-categoria"
            className="text-sm text-muted-foreground"
          >
            Categoria:
          </label>
          <select
            id="filtro-categoria"
            value={filtroCategoria}
            onChange={(e) => setFiltroCategoria(e.target.value)}
            className="h-9 rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="">Todas</option>
            {categorias.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nome}
              </option>
            ))}
          </select>
        </div>
        {podeEscrever && (
          <Button variant="primary" size="sm" onClick={abrirNovo}>
            <Plus aria-hidden />
            Novo produto
          </Button>
        )}
      </div>

      {isLoading && (
        <div
          className="flex items-center gap-2 py-10 text-sm text-muted-foreground"
          role="status"
        >
          <Loader2 className="size-4 animate-spin" aria-hidden />
          Carregando produtos…
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
            <Package className="size-5" aria-hidden />
          </div>
          <p className="font-display font-semibold">Nenhum produto por aqui</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            {filtroCategoria
              ? 'Nenhum produto nesta categoria.'
              : 'Cadastre o primeiro produto do cardápio.'}
          </p>
          {podeEscrever && (
            <Button variant="primary" size="sm" onClick={abrirNovo}>
              <Plus aria-hidden />
              Novo produto
            </Button>
          )}
        </div>
      )}

      {data && data.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <caption className="sr-only">Produtos do catálogo</caption>
            <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Produto</th>
                <th className="px-4 py-2 font-medium">Categoria</th>
                <th className="px-4 py-2 text-right font-medium">Preço</th>
                <th className="px-4 py-2 font-medium">Código PDV</th>
                <th className="px-4 py-2 font-medium">Status</th>
                {podeEscrever && (
                  <th className="px-4 py-2 text-right font-medium">Ações</th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data.map((p) => {
                const codigo = codigoPdvRegem(p);
                return (
                  <tr key={p.id} className="hover:bg-secondary/30">
                    <td className="px-4 py-2">
                      <div className="flex items-center gap-3">
                        {p.imagemUrl ? (
                          <img
                            src={p.imagemUrl}
                            alt=""
                            className="size-10 shrink-0 rounded-md border border-border object-cover"
                          />
                        ) : (
                          <div
                            className="flex size-10 shrink-0 items-center justify-center rounded-md border border-dashed border-border text-muted-foreground"
                            aria-hidden
                          >
                            <ImageOff className="size-4" />
                          </div>
                        )}
                        <div className="min-w-0">
                          <div className="font-medium">{p.nome}</div>
                          {p.descricao && (
                            <div className="max-w-xs truncate text-xs text-muted-foreground">
                              {p.descricao}
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-2 text-muted-foreground">
                      {nomeCategoria(p.categoriaId)}
                    </td>
                    <td className="px-4 py-2 text-right font-mono">
                      {formatarBRL(p.precoCentavos)}
                    </td>
                    <td className="px-4 py-2">
                      {codigo ? (
                        <span className="font-mono text-xs">{codigo}</span>
                      ) : (
                        <Badge variant="outline">sem código</Badge>
                      )}
                    </td>
                    <td className="px-4 py-2">
                      {p.disponivel ? (
                        <Badge variant="success">Disponível</Badge>
                      ) : (
                        <Badge variant="muted">Indisponível</Badge>
                      )}
                    </td>
                    {podeEscrever && (
                      <td className="px-4 py-2">
                        <div className="flex justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="icon"
                            aria-label={
                              p.disponivel
                                ? `Pausar ${p.nome}`
                                : `Despausar ${p.nome}`
                            }
                            title={
                              p.disponivel
                                ? 'Pausar no totem (propaga ao Regem)'
                                : 'Despausar'
                            }
                            disabled={pausar.isPending}
                            onClick={() =>
                              pausar.mutate({
                                id: p.id,
                                pausado: p.disponivel,
                              })
                            }
                          >
                            {p.disponivel ? (
                              <Pause className="size-4" aria-hidden />
                            ) : (
                              <Play className="size-4 text-primary" aria-hidden />
                            )}
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            aria-label={`Complementos de ${p.nome}`}
                            onClick={() => setComplementosDe(p)}
                          >
                            <ListTree className="size-4" aria-hidden />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            aria-label={`Editar ${p.nome}`}
                            onClick={() => abrirEdicao(p)}
                          >
                            <Pencil className="size-4" aria-hidden />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            aria-label={`Excluir ${p.nome}`}
                            onClick={() => setRemovendo(p)}
                          >
                            <Trash2
                              className="size-4 text-destructive"
                              aria-hidden
                            />
                          </Button>
                        </div>
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <ProdutoDialog
        aberto={dialogAberto}
        onFechar={() => setDialogAberto(false)}
        categorias={categorias}
        produto={editando}
      />

      {complementosDe && (
        <ComplementosDialog
          aberto={Boolean(complementosDe)}
          onFechar={() => setComplementosDe(undefined)}
          produto={complementosDe}
        />
      )}

      <ConfirmDialog
        aberto={Boolean(removendo)}
        titulo="Excluir produto"
        descricao={removendo ? `Excluir "${removendo.nome}"?` : ''}
        onConfirmar={async () => {
          if (removendo) await remover.mutateAsync(removendo.id);
        }}
        onFechar={() => setRemovendo(undefined)}
      />
    </section>
  );
}
