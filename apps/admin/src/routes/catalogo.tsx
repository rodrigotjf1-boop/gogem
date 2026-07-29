import * as React from 'react';
import { AlertTriangle } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useCardapios, useSelectedCardapio } from '@/lib/cardapios';
import { CategoriasPanel } from './catalogo/categorias-panel';
import { ProdutosPanel } from './catalogo/produtos-panel';

type Aba = 'produtos' | 'categorias';

/**
 * Catálogo — retaguarda de cardápio (PR C). Abas Produtos/Categorias, cada uma
 * com CRUD contra a API real. Escrita fica visível só para gerente+ (RBAC do
 * front; a autorização real é no servidor).
 */
export default function CatalogoPage() {
  const [aba, setAba] = React.useState<Aba>('produtos');

  return (
    <section className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Catálogo</h1>
        <p className="text-sm text-muted-foreground">
          Categorias, produtos e o de-para PDV que liga o cardápio ao Regem.
        </p>
      </header>

      <CardapioSelector />

      <div
        className="flex gap-1 overflow-x-auto border-b border-border"
        role="tablist"
        aria-label="Seções do catálogo"
      >
        <TabButton
          ativa={aba === 'produtos'}
          onClick={() => setAba('produtos')}
          id="tab-produtos"
        >
          Produtos
        </TabButton>
        <TabButton
          ativa={aba === 'categorias'}
          onClick={() => setAba('categorias')}
          id="tab-categorias"
        >
          Categorias
        </TabButton>
      </div>

      <div
        role="tabpanel"
        aria-labelledby={aba === 'produtos' ? 'tab-produtos' : 'tab-categorias'}
      >
        {aba === 'produtos' ? <ProdutosPanel /> : <CategoriasPanel />}
      </div>
    </section>
  );
}

/** Escolhe qual cardápio o Catálogo edita; avisa quando não é o ativo. */
function CardapioSelector() {
  const { data } = useCardapios();
  const { id, setId } = useSelectedCardapio();
  if (!data || data.length === 0) return null;

  const selecionado = data.find((c) => c.id === id) ?? null;
  const editandoInativo = selecionado ? !selecionado.ativo : false;

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-2">
        <label htmlFor="sel-cardapio" className="text-sm text-muted-foreground">
          Cardápio:
        </label>
        <select
          id="sel-cardapio"
          value={id ?? ''}
          onChange={(e) => setId(e.target.value)}
          className="h-9 rounded-md border border-input bg-background px-3 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {data.map((c) => (
            <option key={c.id} value={c.id}>
              {c.nome}
              {c.ativo ? ' (ativo)' : ''}
            </option>
          ))}
        </select>
      </div>
      {editandoInativo && (
        <p className="flex items-center gap-1.5 rounded-md bg-secondary/50 px-3 py-2 text-xs text-muted-foreground">
          <AlertTriangle className="size-3.5 text-primary" aria-hidden />
          Editando um cardápio inativo — as mudanças não afetam o totem até você
          ativá-lo em <strong>Cardápios</strong>.
        </p>
      )}
    </div>
  );
}

function TabButton({
  ativa,
  onClick,
  id,
  children,
}: {
  ativa: boolean;
  onClick: () => void;
  id: string;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      role="tab"
      id={id}
      aria-selected={ativa}
      onClick={onClick}
      className={cn(
        '-mb-px whitespace-nowrap border-b-2 px-4 py-2 text-sm font-medium transition-colors',
        ativa
          ? 'border-primary text-foreground'
          : 'border-transparent text-muted-foreground hover:text-foreground',
      )}
    >
      {children}
    </button>
  );
}
