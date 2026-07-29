import * as React from 'react';
import { useNavigate } from 'react-router-dom';
import { Copy, Loader2, Pencil, Plus, Power, Trash2 } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import { mensagemDeErro } from '@/lib/publicacao';
import {
  useAtivarCardapio,
  useCardapios,
  useCriarCardapio,
  useExcluirCardapio,
  useRenomearCardapio,
  useSelectedCardapio,
  type Cardapio,
} from '@/lib/cardapios';

type Filtro = 'todos' | 'ativos' | 'inativos';

/**
 * Cardápios (Fase 3B) — até 2 por loja, só 1 ativo. O totem recebe SEMPRE o
 * ativo. O outro serve para preparar uma migração de sistema / testes (criado
 * vazio ou duplicando o ativo). "Gerenciar" abre o Catálogo já naquele cardápio.
 */
export default function CardapiosPage() {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading } = useCardapios();
  const [filtro, setFiltro] = React.useState<Filtro>('todos');
  const [novo, setNovo] = React.useState(false);

  const lista = (data ?? []).filter((c) =>
    filtro === 'ativos' ? c.ativo : filtro === 'inativos' ? !c.ativo : true,
  );
  const noLimite = (data?.length ?? 0) >= 2;

  return (
    <section className="mx-auto max-w-5xl space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-1">
          <h1 className="text-2xl font-bold">Cardápios</h1>
          <p className="text-sm text-muted-foreground">
            Até 2 cardápios; só o <strong>ativo</strong> aparece no totem e recebe
            as alterações. Use o outro para preparar uma troca de sistema.
          </p>
        </div>
        {podeEscrever && (
          <Button
            variant="primary"
            size="sm"
            onClick={() => setNovo(true)}
            disabled={noLimite}
            title={noLimite ? 'Limite de 2 cardápios atingido.' : undefined}
          >
            <Plus aria-hidden />
            Novo cardápio
          </Button>
        )}
      </header>

      <div className="flex flex-wrap gap-2">
        {(['todos', 'ativos', 'inativos'] as Filtro[]).map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => setFiltro(f)}
            aria-pressed={filtro === f}
            className={`rounded-full border px-3 py-1 text-sm capitalize transition-colors ${
              filtro === f
                ? 'border-primary bg-secondary text-foreground'
                : 'border-border text-muted-foreground hover:text-foreground'
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="flex justify-center py-16 text-muted-foreground">
          <Loader2 className="size-6 animate-spin" aria-hidden />
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {lista.map((c) => (
            <CardapioCard key={c.id} cardapio={c} podeEscrever={podeEscrever} />
          ))}
        </div>
      )}

      {novo && <NovoCardapioDialog onFechar={() => setNovo(false)} />}
    </section>
  );
}

function CardapioCard({
  cardapio,
  podeEscrever,
}: {
  cardapio: Cardapio;
  podeEscrever: boolean;
}) {
  const navigate = useNavigate();
  const { setId } = useSelectedCardapio();
  const ativar = useAtivarCardapio();
  const excluir = useExcluirCardapio();
  const [renomear, setRenomear] = React.useState(false);
  const [confirmarExcluir, setConfirmarExcluir] = React.useState(false);

  function gerenciar() {
    setId(cardapio.id);
    navigate('/catalogo');
  }

  return (
    <Card className="flex flex-col">
      <CardContent className="flex flex-1 flex-col gap-3 p-5">
        <div className="flex items-start justify-between gap-2">
          <p className="font-display text-lg font-semibold">{cardapio.nome}</p>
          {cardapio.ativo ? (
            <Badge variant="success">Ativo</Badge>
          ) : (
            <Badge variant="outline">Inativo</Badge>
          )}
        </div>
        <p className="text-sm text-muted-foreground">
          {cardapio.produtos} produto(s)
          {cardapio.ativo && ' · exposto no totem'}
        </p>

        <div className="mt-auto flex flex-wrap gap-2 pt-2">
          <Button variant="outline" size="sm" onClick={gerenciar}>
            Gerenciar
          </Button>
          {podeEscrever && (
            <>
              {!cardapio.ativo && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => ativar.mutate(cardapio.id)}
                  disabled={ativar.isPending}
                >
                  {ativar.isPending ? (
                    <Loader2 className="animate-spin" aria-hidden />
                  ) : (
                    <Power aria-hidden />
                  )}
                  Ativar
                </Button>
              )}
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setRenomear(true)}
                aria-label={`Renomear ${cardapio.nome}`}
              >
                <Pencil className="size-4" aria-hidden />
              </Button>
              {!cardapio.ativo && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setConfirmarExcluir(true)}
                  aria-label={`Excluir ${cardapio.nome}`}
                >
                  <Trash2 className="size-4 text-destructive" aria-hidden />
                </Button>
              )}
            </>
          )}
        </div>
      </CardContent>

      {renomear && (
        <RenomearDialog cardapio={cardapio} onFechar={() => setRenomear(false)} />
      )}
      <ConfirmDialog
        aberto={confirmarExcluir}
        titulo="Excluir cardápio"
        descricao={`Excluir "${cardapio.nome}" e todo o seu conteúdo? Esta ação não pode ser desfeita.`}
        onConfirmar={async () => {
          await excluir.mutateAsync(cardapio.id);
        }}
        onFechar={() => setConfirmarExcluir(false)}
      />
    </Card>
  );
}

function NovoCardapioDialog({ onFechar }: { onFechar: () => void }) {
  const criar = useCriarCardapio();
  const [nome, setNome] = React.useState('');
  const [modo, setModo] = React.useState<'vazio' | 'duplicar'>('vazio');
  const [erro, setErro] = React.useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    if (!nome.trim()) {
      setErro('Informe o nome do cardápio.');
      return;
    }
    try {
      await criar.mutateAsync({ nome: nome.trim(), modo });
      onFechar();
    } catch (err) {
      setErro(mensagemDeErro(err));
    }
  }

  return (
    <Dialog
      aberto
      onFechar={onFechar}
      titulo="Novo cardápio"
      descricao="Nasce inativo. Ative quando estiver pronto para o totem."
    >
      <form className="space-y-4" onSubmit={onSubmit} noValidate>
        <div className="space-y-2">
          <Label htmlFor="card-nome">Nome</Label>
          <Input
            id="card-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="Cardápio novo sistema"
            disabled={criar.isPending}
            autoFocus
          />
        </div>

        <fieldset className="space-y-2">
          <legend className="text-sm font-medium">Conteúdo inicial</legend>
          <label className="flex items-start gap-2 rounded-md border border-border p-3 text-sm">
            <input
              type="radio"
              name="modo"
              checked={modo === 'vazio'}
              onChange={() => setModo('vazio')}
              className="mt-1 accent-[hsl(var(--primary))]"
            />
            <span>
              <span className="font-medium">Vazio</span>
              <span className="block text-xs text-muted-foreground">
                Estrutura zerada — para montar do zero ou importar de um sistema.
              </span>
            </span>
          </label>
          <label className="flex items-start gap-2 rounded-md border border-border p-3 text-sm">
            <input
              type="radio"
              name="modo"
              checked={modo === 'duplicar'}
              onChange={() => setModo('duplicar')}
              className="mt-1 accent-[hsl(var(--primary))]"
            />
            <span>
              <span className="flex items-center gap-1 font-medium">
                <Copy className="size-3.5" aria-hidden /> Duplicar o ativo
              </span>
              <span className="block text-xs text-muted-foreground">
                Cópia do cardápio ativo para editar/testar sem afetar o totem.
              </span>
            </span>
          </label>
        </fieldset>

        {erro && (
          <p role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
            {erro}
          </p>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={onFechar} disabled={criar.isPending}>
            Cancelar
          </Button>
          <Button type="submit" variant="primary" disabled={criar.isPending}>
            {criar.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Criar cardápio
          </Button>
        </div>
      </form>
    </Dialog>
  );
}

function RenomearDialog({
  cardapio,
  onFechar,
}: {
  cardapio: Cardapio;
  onFechar: () => void;
}) {
  const renomear = useRenomearCardapio();
  const [nome, setNome] = React.useState(cardapio.nome);
  const [erro, setErro] = React.useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!nome.trim()) return;
    setErro(null);
    try {
      await renomear.mutateAsync({ id: cardapio.id, nome: nome.trim() });
      onFechar();
    } catch (err) {
      setErro(mensagemDeErro(err));
    }
  }

  return (
    <Dialog aberto onFechar={onFechar} titulo="Renomear cardápio">
      <form className="space-y-4" onSubmit={onSubmit} noValidate>
        <div className="space-y-2">
          <Label htmlFor="ren-nome">Nome</Label>
          <Input
            id="ren-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            disabled={renomear.isPending}
            autoFocus
          />
        </div>
        {erro && <p className="text-sm text-destructive">{erro}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={onFechar} disabled={renomear.isPending}>
            Cancelar
          </Button>
          <Button type="submit" variant="primary" disabled={renomear.isPending}>
            {renomear.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Salvar
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
