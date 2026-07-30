import * as React from 'react';
import { Check, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { usePodeEscrever } from '@/auth/auth-context';
import { formatarBRL } from '@/lib/money';
import {
  useProdutos,
  useSalvarUpsells,
  useUpsells,
  type Produto,
} from '@/lib/catalogo';

/**
 * Editor de upsell "Peça também" (F2). O lojista escolhe, entre os produtos
 * cadastrados, quais sugerir quando este produto está no carrinho. A ordem de
 * seleção é a ordem de exibição no totem. Só gerente+ edita.
 */
export function UpsellDialog({
  aberto,
  onFechar,
  produto,
}: {
  aberto: boolean;
  onFechar: () => void;
  produto: Produto;
}) {
  const podeEscrever = usePodeEscrever();
  const { data: atuais, isLoading: carregandoAtuais } = useUpsells(produto.id);
  const { data: produtos, isLoading: carregandoProdutos } = useProdutos();
  const salvar = useSalvarUpsells(produto.id);

  // Lista ORDENADA de ids selecionados (a ordem = ordem de exibição).
  const [sel, setSel] = React.useState<string[] | null>(null);
  const [erro, setErro] = React.useState<string | null>(null);

  // Inicializa a seleção a partir do que já está salvo (uma vez, ao abrir).
  React.useEffect(() => {
    if (atuais && sel === null) setSel(atuais.map((u) => u.sugeridoId));
  }, [atuais, sel]);

  const selecao = sel ?? [];
  const candidatos = (produtos ?? []).filter((p) => p.id !== produto.id);

  function alternar(id: string) {
    setErro(null);
    setSel((cur) => {
      const base = cur ?? [];
      return base.includes(id)
        ? base.filter((x) => x !== id)
        : [...base, id];
    });
  }

  async function onSalvar() {
    try {
      await salvar.mutateAsync(selecao);
      onFechar();
    } catch {
      setErro('Não foi possível salvar. Tente novamente.');
    }
  }

  const carregando = carregandoAtuais || carregandoProdutos || sel === null;

  return (
    <Dialog
      aberto={aberto}
      onFechar={onFechar}
      titulo={`Peça também — ${produto.nome}`}
      descricao="Escolha os produtos a sugerir no checkout. A ordem de seleção é a ordem exibida no totem."
      larguraClasse="max-w-lg"
    >
      {carregando ? (
        <div
          className="flex items-center gap-2 py-10 text-sm text-muted-foreground"
          role="status"
        >
          <Loader2 className="size-4 animate-spin" aria-hidden />
          Carregando produtos…
        </div>
      ) : candidatos.length === 0 ? (
        <p className="py-10 text-center text-sm text-muted-foreground">
          Cadastre outros produtos neste cardápio para poder sugeri-los.
        </p>
      ) : (
        <div className="space-y-4">
          <ul className="max-h-80 space-y-1 overflow-y-auto">
            {candidatos.map((c) => {
              const pos = selecao.indexOf(c.id);
              const ativo = pos >= 0;
              return (
                <li key={c.id}>
                  <button
                    type="button"
                    disabled={!podeEscrever}
                    aria-pressed={ativo}
                    onClick={() => alternar(c.id)}
                    className={
                      'flex w-full items-center gap-3 rounded-md border px-3 py-2 text-left transition-colors ' +
                      (ativo
                        ? 'border-primary bg-primary/10'
                        : 'border-border hover:bg-secondary/40')
                    }
                  >
                    <span
                      className={
                        'flex size-6 shrink-0 items-center justify-center rounded-full text-xs font-bold ' +
                        (ativo
                          ? 'bg-primary text-primary-foreground'
                          : 'border border-border text-muted-foreground')
                      }
                    >
                      {ativo ? pos + 1 : ''}
                    </span>
                    <ProdutoMini produto={c} />
                    {ativo && (
                      <Check
                        className="ml-auto size-4 text-primary"
                        aria-hidden
                      />
                    )}
                  </button>
                </li>
              );
            })}
          </ul>

          {erro && <p className="text-xs text-destructive">{erro}</p>}

          <div className="flex items-center justify-between gap-3 pt-1">
            <span className="text-xs text-muted-foreground">
              {selecao.length} selecionado(s)
            </span>
            <div className="flex gap-2">
              <Button variant="outline" onClick={onFechar}>
                Cancelar
              </Button>
              {podeEscrever && (
                <Button
                  variant="primary"
                  onClick={onSalvar}
                  disabled={salvar.isPending}
                >
                  {salvar.isPending && (
                    <Loader2 className="animate-spin" aria-hidden />
                  )}
                  Salvar
                </Button>
              )}
            </div>
          </div>
        </div>
      )}
    </Dialog>
  );
}

function ProdutoMini({ produto }: { produto: Produto }) {
  return (
    <span className="flex min-w-0 items-center gap-2">
      {produto.imagemUrl && (
        <img
          src={produto.imagemUrl}
          alt=""
          className="size-8 shrink-0 rounded object-cover"
        />
      )}
      <span className="truncate font-medium">{produto.nome}</span>
      <span className="shrink-0 font-mono text-xs text-muted-foreground">
        {formatarBRL(produto.precoCentavos)}
      </span>
    </span>
  );
}
