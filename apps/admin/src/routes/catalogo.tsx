import * as React from 'react';
import { cn } from '@/lib/utils';
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
