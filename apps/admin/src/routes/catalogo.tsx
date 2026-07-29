import { AlertTriangle } from 'lucide-react';
import { useCardapios, useSelectedCardapio } from '@/lib/cardapios';
import { CatalogoArvore } from './catalogo/catalogo-arvore';

/**
 * Catálogo — árvore Categoria → Produto → Complemento → Opção (espelha o Regem):
 * categorias à esquerda, produtos agrupados à direita. Escrita só para gerente+
 * (RBAC do front; a autorização real é no servidor). O seletor de cardápio
 * define qual cardápio está em edição.
 */
export default function CatalogoPage() {
  return (
    <section className="space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Catálogo</h1>
        <p className="text-sm text-muted-foreground">
          Categorias, produtos e o de-para PDV que liga o cardápio ao Regem.
        </p>
      </header>

      <CardapioSelector />

      <CatalogoArvore />
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
