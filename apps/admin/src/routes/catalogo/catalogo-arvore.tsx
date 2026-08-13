import * as React from 'react';
import {
  ImageOff,
  ListTree,
  Loader2,
  Pause,
  Pencil,
  Play,
  Plus,
  Sparkles,
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
  usePausarCategoria,
  usePausarProduto,
  useProdutos,
  useRemoverCategoria,
  useRemoverProduto,
  type Categoria,
  type Produto,
} from '@/lib/catalogo';
import { ProdutoDialog } from './produto-dialog';
import { CategoriaDialog } from './categoria-dialog';
import { ComplementosDialog } from './complementos-dialog';
import { UpsellDialog } from './upsell-dialog';

/**
 * Catálogo em árvore (espelha o Regem): categorias numa coluna à esquerda +
 * produtos agrupados por categoria à direita, na ordem das categorias. Um padrão
 * único que também facilita a integração (mesma hierarquia do de-para PDV).
 */
export function CatalogoArvore() {
  const podeEscrever = usePodeEscrever();
  const { data: categorias } = useCategorias();
  const { data: produtos, isLoading, isError } = useProdutos();

  const [sel, setSel] = React.useState<string>('todas'); // categoria selecionada
  const [novoProduto, setNovoProduto] = React.useState(false);
  const [editandoProduto, setEditandoProduto] = React.useState<Produto>();
  const [novaCategoria, setNovaCategoria] = React.useState(false);
  const [editandoCategoria, setEditandoCategoria] = React.useState<Categoria>();

  const cats = React.useMemo(
    () => [...(categorias ?? [])].sort((a, b) => a.ordem - b.ordem),
    [categorias],
  );

  // Grupos na ordem das categorias + "Sem categoria" ao fim.
  const grupos = React.useMemo(() => {
    const porCat = new Map<string | null, Produto[]>();
    for (const p of produtos ?? []) {
      const k = p.categoriaId ?? null;
      (porCat.get(k) ?? porCat.set(k, []).get(k)!).push(p);
    }
    const out: { id: string | null; nome: string; itens: Produto[] }[] = [];
    for (const c of cats) {
      if (porCat.has(c.id)) out.push({ id: c.id, nome: c.nome, itens: porCat.get(c.id)! });
    }
    if (porCat.has(null))
      out.push({ id: null, nome: 'Sem categoria', itens: porCat.get(null)! });
    return out;
  }, [produtos, cats]);

  const gruposVisiveis =
    sel === 'todas' ? grupos : grupos.filter((g) => g.id === sel);

  return (
    <div className="grid gap-4 lg:grid-cols-[240px_1fr]">
      {/* Coluna de categorias */}
      <aside className="space-y-2">
        <div className="flex items-center justify-between">
          <h2 className="font-display text-sm font-semibold uppercase tracking-wide text-muted-foreground">
            Categorias
          </h2>
          {podeEscrever && (
            <Button
              variant="ghost"
              size="icon"
              aria-label="Nova categoria"
              onClick={() => setNovaCategoria(true)}
            >
              <Plus className="size-4" aria-hidden />
            </Button>
          )}
        </div>
        <ul className="space-y-1">
          <CategoriaItem
            nome="Todas as categorias"
            ativa={sel === 'todas'}
            onSelect={() => setSel('todas')}
          />
          {cats.map((c) => (
            <CategoriaItem
              key={c.id}
              nome={c.nome}
              ativa={sel === c.id}
              onSelect={() => setSel(c.id)}
              onEditar={podeEscrever ? () => setEditandoCategoria(c) : undefined}
              categoria={podeEscrever ? c : undefined}
            />
          ))}
          {cats.length === 0 && (
            <li className="px-3 py-2 text-xs text-muted-foreground">
              Nenhuma categoria ainda.
            </li>
          )}
        </ul>
      </aside>

      {/* Coluna de produtos */}
      <div className="space-y-4">
        <div className="flex items-center justify-end">
          {podeEscrever && (
            <Button variant="primary" size="sm" onClick={() => setNovoProduto(true)}>
              <Plus aria-hidden />
              Novo produto
            </Button>
          )}
        </div>

        {isLoading && (
          <div className="flex justify-center py-16 text-muted-foreground">
            <Loader2 className="size-6 animate-spin" aria-hidden />
          </div>
        )}
        {isError && (
          <p role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
            Não foi possível carregar os produtos.
          </p>
        )}
        {!isLoading && gruposVisiveis.length === 0 && (
          <div className="rounded-lg border border-dashed border-border px-4 py-12 text-center text-sm text-muted-foreground">
            <p className="font-medium text-foreground">Nenhum produto por aqui</p>
            <p className="mt-1">
              Crie categorias e produtos para montar o cardápio.
            </p>
          </div>
        )}

        {gruposVisiveis.map((g) => (
          <section key={g.id ?? 'sem'} className="space-y-2">
            <div className="flex items-center gap-2">
              <h3 className="font-display font-semibold">{g.nome}</h3>
              <Badge variant="outline">{g.itens.length} itens</Badge>
            </div>
            <ul className="divide-y divide-border overflow-hidden rounded-lg border border-border">
              {g.itens.map((p) => (
                <ProdutoLinha
                  key={p.id}
                  produto={p}
                  podeEscrever={podeEscrever}
                  onEditar={() => setEditandoProduto(p)}
                />
              ))}
            </ul>
          </section>
        ))}
      </div>

      {/* Diálogos */}
      <ProdutoDialog
        aberto={novoProduto || Boolean(editandoProduto)}
        onFechar={() => {
          setNovoProduto(false);
          setEditandoProduto(undefined);
        }}
        categorias={cats}
        produto={editandoProduto}
      />
      <CategoriaDialog
        aberto={novaCategoria || Boolean(editandoCategoria)}
        onFechar={() => {
          setNovaCategoria(false);
          setEditandoCategoria(undefined);
        }}
        categoria={editandoCategoria}
      />
    </div>
  );
}

function CategoriaItem({
  nome,
  ativa,
  onSelect,
  onEditar,
  categoria,
}: {
  nome: string;
  ativa: boolean;
  onSelect: () => void;
  onEditar?: () => void;
  /** Categoria real (habilita pausar/excluir). Ausente = item "Todas". */
  categoria?: Categoria;
}) {
  const pausar = usePausarCategoria();
  const remover = useRemoverCategoria();
  const [removendo, setRemovendo] = React.useState(false);
  const pausada = categoria?.pausada ?? false;

  return (
    <li className="group flex items-center">
      <button
        type="button"
        onClick={onSelect}
        aria-pressed={ativa}
        className={`flex-1 truncate rounded-md px-3 py-2 text-left text-sm transition-colors ${
          ativa
            ? 'bg-secondary font-medium text-foreground'
            : 'text-muted-foreground hover:bg-secondary/50 hover:text-foreground'
        }`}
      >
        {nome}
        {pausada && (
          <Badge variant="outline" className="ml-2 align-middle">
            pausada
          </Badge>
        )}
      </button>
      {categoria && (
        <div className="flex items-center opacity-0 group-hover:opacity-100">
          <Button
            variant="ghost"
            size="icon"
            aria-label={pausada ? `Despausar ${nome}` : `Pausar ${nome}`}
            title={
              pausada
                ? 'Despausar (volta ao totem)'
                : 'Pausar a categoria inteira no totem'
            }
            disabled={pausar.isPending}
            onClick={() =>
              pausar.mutate({ id: categoria.id, pausada: !pausada })
            }
          >
            {pausada ? (
              <Play className="size-3.5 text-primary" aria-hidden />
            ) : (
              <Pause className="size-3.5" aria-hidden />
            )}
          </Button>
          {onEditar && (
            <Button
              variant="ghost"
              size="icon"
              aria-label={`Editar ${nome}`}
              onClick={onEditar}
            >
              <Pencil className="size-3.5" aria-hidden />
            </Button>
          )}
          <Button
            variant="ghost"
            size="icon"
            aria-label={`Excluir ${nome}`}
            onClick={() => setRemovendo(true)}
          >
            <Trash2 className="size-3.5 text-destructive" aria-hidden />
          </Button>
        </div>
      )}

      {categoria && (
        <ConfirmDialog
          aberto={removendo}
          titulo="Excluir categoria"
          descricao={`Excluir "${nome}"? Categoria com produtos vinculados não pode ser excluída — realoque ou exclua os produtos antes.`}
          onConfirmar={async () => {
            await remover.mutateAsync(categoria.id);
          }}
          onFechar={() => setRemovendo(false)}
        />
      )}
    </li>
  );
}

function ProdutoLinha({
  produto: p,
  podeEscrever,
  onEditar,
}: {
  produto: Produto;
  podeEscrever: boolean;
  onEditar: () => void;
}) {
  const pausar = usePausarProduto();
  const remover = useRemoverProduto();
  const [complementos, setComplementos] = React.useState(false);
  const [upsell, setUpsell] = React.useState(false);
  const [removendo, setRemovendo] = React.useState(false);
  const codigo = codigoPdvRegem(p);

  return (
    <li className="flex flex-wrap items-center gap-3 px-3 py-2.5 hover:bg-secondary/20">
      {p.imagemUrl ? (
        <img
          src={p.imagemUrl}
          alt=""
          className="size-11 shrink-0 rounded-md border border-border object-cover"
        />
      ) : (
        <div
          className="flex size-11 shrink-0 items-center justify-center rounded-md border border-dashed border-border text-muted-foreground"
          aria-hidden
        >
          <ImageOff className="size-4" />
        </div>
      )}

      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className="font-medium">{p.nome}</span>
          {codigo ? (
            <span className="font-mono text-xs text-muted-foreground">{codigo}</span>
          ) : (
            <Badge variant="outline">sem código</Badge>
          )}
          <Badge variant={p.disponivel ? 'success' : 'outline'}>
            {p.disponivel ? 'Disponível' : 'Indisponível'}
          </Badge>
        </div>
        {p.descricao && (
          <p className="max-w-md truncate text-xs text-muted-foreground">
            {p.descricao}
          </p>
        )}
      </div>

      <span className="font-mono text-sm">{formatarBRL(p.precoCentavos)}</span>

      {podeEscrever && (
        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            aria-label={p.disponivel ? `Pausar ${p.nome}` : `Despausar ${p.nome}`}
            title={p.disponivel ? 'Pausar no totem (propaga ao Regem)' : 'Despausar'}
            disabled={pausar.isPending}
            onClick={() => pausar.mutate({ id: p.id, pausado: p.disponivel })}
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
            onClick={() => setComplementos(true)}
          >
            <ListTree className="size-4" aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label={`Peça também de ${p.nome}`}
            title="Peça também (upsell)"
            onClick={() => setUpsell(true)}
          >
            <Sparkles className="size-4" aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label={`Editar ${p.nome}`}
            onClick={onEditar}
          >
            <Pencil className="size-4" aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label={`Excluir ${p.nome}`}
            onClick={() => setRemovendo(true)}
          >
            <Trash2 className="size-4 text-destructive" aria-hidden />
          </Button>
        </div>
      )}

      {complementos && (
        <ComplementosDialog
          aberto={complementos}
          onFechar={() => setComplementos(false)}
          produto={p}
        />
      )}
      {upsell && (
        <UpsellDialog
          aberto={upsell}
          onFechar={() => setUpsell(false)}
          produto={p}
        />
      )}
      <ConfirmDialog
        aberto={removendo}
        titulo="Excluir produto"
        descricao={`Excluir "${p.nome}"?`}
        onConfirmar={async () => {
          await remover.mutateAsync(p.id);
        }}
        onFechar={() => setRemovendo(false)}
      />
    </li>
  );
}
