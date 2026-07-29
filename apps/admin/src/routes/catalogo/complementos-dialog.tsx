import * as React from 'react';
import { Loader2, Pencil, Plus, Trash2, X } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import { centavosParaReais, formatarBRL, reaisParaCentavos } from '@/lib/money';
import {
  codigoPdvOpcao,
  useAtualizarGrupo,
  useAtualizarOpcao,
  useCriarGrupo,
  useCriarOpcao,
  useGrupos,
  useRemoverGrupo,
  useRemoverOpcao,
  type ExternalRef,
  type Grupo,
  type GrupoInput,
  type Opcao,
  type OpcaoInput,
  type Produto,
} from '@/lib/catalogo';

/**
 * Editor de complementos de um produto (Fase 3) — espelha a árvore do Regem:
 * produto → etapa (grupo) → opção. A OPÇÃO carrega o código PDV; opção sem
 * código é "informativa" (nota, sem lançar no PDV). Só gerente+ edita.
 */
export function ComplementosDialog({
  aberto,
  onFechar,
  produto,
}: {
  aberto: boolean;
  onFechar: () => void;
  produto: Produto;
}) {
  const podeEscrever = usePodeEscrever();
  const { data: grupos, isLoading } = useGrupos(produto.id, aberto);
  const [novaEtapa, setNovaEtapa] = React.useState(false);

  return (
    <Dialog
      aberto={aberto}
      onFechar={onFechar}
      titulo={`Complementos · ${produto.nome}`}
      descricao="Etapas e opções. A opção com código PDV lança no Regem; sem código, é informativa."
    >
      <div className="space-y-4">
        {isLoading && (
          <div className="flex justify-center py-8 text-muted-foreground">
            <Loader2 className="size-5 animate-spin" aria-hidden />
          </div>
        )}

        {grupos?.length === 0 && !novaEtapa && (
          <p className="rounded-md border border-dashed border-border px-4 py-6 text-center text-sm text-muted-foreground">
            Nenhuma etapa ainda. Ex.: “Escolha a bebida”, “Adicionais”.
          </p>
        )}

        {grupos?.map((g) => (
          <GrupoCard
            key={g.id}
            grupo={g}
            produtoId={produto.id}
            podeEscrever={podeEscrever}
          />
        ))}

        {novaEtapa ? (
          <GrupoForm
            produtoId={produto.id}
            onPronto={() => setNovaEtapa(false)}
            onCancelar={() => setNovaEtapa(false)}
          />
        ) : (
          podeEscrever && (
            <Button variant="outline" size="sm" onClick={() => setNovaEtapa(true)}>
              <Plus aria-hidden />
              Adicionar etapa
            </Button>
          )
        )}

        <div className="flex justify-end pt-2">
          <Button type="button" variant="ghost" onClick={onFechar}>
            Fechar
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function GrupoCard({
  grupo,
  produtoId,
  podeEscrever,
}: {
  grupo: Grupo;
  produtoId: string;
  podeEscrever: boolean;
}) {
  const remover = useRemoverGrupo(produtoId);
  const [editando, setEditando] = React.useState(false);
  const [novaOpcao, setNovaOpcao] = React.useState(false);

  const regra =
    (grupo.max ?? 0) === 1 && grupo.min > 0
      ? 'escolha 1'
      : grupo.max
        ? `${grupo.min}–${grupo.max}`
        : `min ${grupo.min}`;

  return (
    <div className="rounded-lg border border-border">
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border bg-secondary/30 px-4 py-2">
        <div className="flex items-center gap-2">
          <span className="font-display font-semibold">{grupo.nome}</span>
          <Badge variant="outline">{regra}</Badge>
          {grupo.obrigatorio && <Badge variant="success">obrigatória</Badge>}
        </div>
        {podeEscrever && (
          <div className="flex gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setEditando((v) => !v)}
              aria-label={`Editar etapa ${grupo.nome}`}
            >
              <Pencil className="size-4" aria-hidden />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => remover.mutate(grupo.id)}
              disabled={remover.isPending}
              aria-label={`Remover etapa ${grupo.nome}`}
            >
              <Trash2 className="size-4 text-destructive" aria-hidden />
            </Button>
          </div>
        )}
      </div>

      {editando && (
        <div className="border-b border-border p-4">
          <GrupoForm
            produtoId={produtoId}
            grupo={grupo}
            onPronto={() => setEditando(false)}
            onCancelar={() => setEditando(false)}
          />
        </div>
      )}

      <ul className="divide-y divide-border">
        {grupo.opcoes.length === 0 && (
          <li className="px-4 py-3 text-sm text-muted-foreground">
            Sem opções nesta etapa.
          </li>
        )}
        {grupo.opcoes.map((o) => (
          <OpcaoRow
            key={o.id}
            opcao={o}
            produtoId={produtoId}
            podeEscrever={podeEscrever}
          />
        ))}
      </ul>

      {podeEscrever && (
        <div className="px-4 py-3">
          {novaOpcao ? (
            <OpcaoForm
              produtoId={produtoId}
              grupoId={grupo.id}
              onPronto={() => setNovaOpcao(false)}
              onCancelar={() => setNovaOpcao(false)}
            />
          ) : (
            <Button variant="ghost" size="sm" onClick={() => setNovaOpcao(true)}>
              <Plus aria-hidden />
              Adicionar opção
            </Button>
          )}
        </div>
      )}
    </div>
  );
}

function OpcaoRow({
  opcao,
  produtoId,
  podeEscrever,
}: {
  opcao: Opcao;
  produtoId: string;
  podeEscrever: boolean;
}) {
  const remover = useRemoverOpcao(produtoId);
  const [editando, setEditando] = React.useState(false);
  const codigo = codigoPdvOpcao(opcao);

  if (editando) {
    return (
      <li className="p-4">
        <OpcaoForm
          produtoId={produtoId}
          grupoId={opcao.grupoId}
          opcao={opcao}
          onPronto={() => setEditando(false)}
          onCancelar={() => setEditando(false)}
        />
      </li>
    );
  }

  return (
    <li className="flex flex-wrap items-center justify-between gap-2 px-4 py-2">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <span className={opcao.disponivel ? '' : 'text-muted-foreground line-through'}>
            {opcao.nome}
          </span>
          {codigo ? (
            <span className="font-mono text-xs text-muted-foreground">{codigo}</span>
          ) : (
            <Badge variant="outline">informativa</Badge>
          )}
          {!opcao.disponivel && <Badge variant="outline">indisponível</Badge>}
        </div>
      </div>
      <div className="flex items-center gap-2">
        {opcao.precoCentavosDelta !== 0 && (
          <span className="font-mono text-sm text-primary">
            {opcao.precoCentavosDelta > 0 ? '+' : ''}
            {formatarBRL(opcao.precoCentavosDelta)}
          </span>
        )}
        {podeEscrever && (
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setEditando(true)}
              aria-label={`Editar opção ${opcao.nome}`}
            >
              <Pencil className="size-4" aria-hidden />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => remover.mutate(opcao.id)}
              disabled={remover.isPending}
              aria-label={`Remover opção ${opcao.nome}`}
            >
              <Trash2 className="size-4 text-destructive" aria-hidden />
            </Button>
          </>
        )}
      </div>
    </li>
  );
}

// ————————————————————————— Formulários inline —————————————————————————

function GrupoForm({
  produtoId,
  grupo,
  onPronto,
  onCancelar,
}: {
  produtoId: string;
  grupo?: Grupo;
  onPronto: () => void;
  onCancelar: () => void;
}) {
  const criar = useCriarGrupo(produtoId);
  const atualizar = useAtualizarGrupo(produtoId);
  const [nome, setNome] = React.useState(grupo?.nome ?? '');
  const [min, setMin] = React.useState(String(grupo?.min ?? 0));
  const [max, setMax] = React.useState(grupo?.max != null ? String(grupo.max) : '');
  const [obrigatorio, setObrigatorio] = React.useState(grupo?.obrigatorio ?? false);
  const [erro, setErro] = React.useState<string | null>(null);
  const enviando = criar.isPending || atualizar.isPending;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    if (!nome.trim()) {
      setErro('Informe o nome da etapa.');
      return;
    }
    const input: GrupoInput = {
      nome: nome.trim(),
      min: Number(min) || 0,
      max: max.trim() === '' ? undefined : Number(max),
      obrigatorio,
    };
    if (input.max != null && input.max < (input.min ?? 0)) {
      setErro('O máximo não pode ser menor que o mínimo.');
      return;
    }
    try {
      if (grupo) await atualizar.mutateAsync({ id: grupo.id, input });
      else await criar.mutateAsync(input);
      onPronto();
    } catch {
      setErro('Não foi possível salvar a etapa.');
    }
  }

  return (
    <form className="space-y-3" onSubmit={onSubmit} noValidate>
      <div className="space-y-1">
        <Label htmlFor="grp-nome">Nome da etapa</Label>
        <Input
          id="grp-nome"
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          placeholder="Escolha a bebida"
          disabled={enviando}
          autoFocus
        />
      </div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <div className="space-y-1">
          <Label htmlFor="grp-min">Mínimo</Label>
          <Input
            id="grp-min"
            inputMode="numeric"
            value={min}
            onChange={(e) => setMin(e.target.value.replace(/\D/g, ''))}
            disabled={enviando}
          />
        </div>
        <div className="space-y-1">
          <Label htmlFor="grp-max">Máximo</Label>
          <Input
            id="grp-max"
            inputMode="numeric"
            value={max}
            onChange={(e) => setMax(e.target.value.replace(/\D/g, ''))}
            placeholder="ilimitado"
            disabled={enviando}
          />
        </div>
        <label className="flex items-end gap-2 pb-2 text-sm">
          <input
            type="checkbox"
            checked={obrigatorio}
            onChange={(e) => setObrigatorio(e.target.checked)}
            disabled={enviando}
            className="size-4 rounded border-input accent-[hsl(var(--primary))]"
          />
          Obrigatória
        </label>
      </div>
      {erro && <p className="text-xs text-destructive">{erro}</p>}
      <div className="flex gap-2">
        <Button type="submit" variant="primary" size="sm" disabled={enviando}>
          {enviando && <Loader2 className="animate-spin" aria-hidden />}
          {grupo ? 'Salvar etapa' : 'Criar etapa'}
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={onCancelar} disabled={enviando}>
          <X aria-hidden />
          Cancelar
        </Button>
      </div>
    </form>
  );
}

function OpcaoForm({
  produtoId,
  grupoId,
  opcao,
  onPronto,
  onCancelar,
}: {
  produtoId: string;
  grupoId: string;
  opcao?: Opcao;
  onPronto: () => void;
  onCancelar: () => void;
}) {
  const criar = useCriarOpcao(produtoId);
  const atualizar = useAtualizarOpcao(produtoId);
  const [nome, setNome] = React.useState(opcao?.nome ?? '');
  const [preco, setPreco] = React.useState(
    opcao ? centavosParaReais(opcao.precoCentavosDelta) : '',
  );
  const [codigo, setCodigo] = React.useState(
    opcao ? (codigoPdvOpcao(opcao) ?? '') : '',
  );
  const [disponivel, setDisponivel] = React.useState(opcao?.disponivel ?? true);
  const [erro, setErro] = React.useState<string | null>(null);
  const enviando = criar.isPending || atualizar.isPending;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    if (!nome.trim()) {
      setErro('Informe o nome da opção.');
      return;
    }
    const cod = codigo.trim();
    const externalRefs: ExternalRef[] = cod
      ? [{ sistema: 'regem', codigo_pdv: cod }]
      : [];
    const input: OpcaoInput = {
      nome: nome.trim(),
      precoCentavosDelta: reaisParaCentavos(preco) ?? 0,
      disponivel,
      externalRefs,
    };
    try {
      if (opcao) await atualizar.mutateAsync({ id: opcao.id, input });
      else await criar.mutateAsync({ grupoId, input });
      onPronto();
    } catch {
      setErro('Não foi possível salvar a opção.');
    }
  }

  return (
    <form className="space-y-3 rounded-md border border-border bg-secondary/20 p-3" onSubmit={onSubmit} noValidate>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1">
          <Label htmlFor="op-nome">Nome da opção</Label>
          <Input
            id="op-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="Coca-Cola lata"
            disabled={enviando}
            autoFocus
          />
        </div>
        <div className="space-y-1">
          <Label htmlFor="op-preco">Acréscimo (R$)</Label>
          <Input
            id="op-preco"
            inputMode="decimal"
            value={preco}
            onChange={(e) => setPreco(e.target.value)}
            placeholder="0,00"
            disabled={enviando}
          />
        </div>
      </div>
      <div className="space-y-1">
        <Label htmlFor="op-codigo">Código PDV (Regem)</Label>
        <Input
          id="op-codigo"
          value={codigo}
          onChange={(e) => setCodigo(e.target.value)}
          placeholder="deixe em branco = informativa"
          disabled={enviando}
          className="font-mono"
        />
        <p className="text-xs text-muted-foreground">
          Sem código, a opção é <strong>informativa</strong> (nota, não lança no PDV).
        </p>
      </div>
      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={disponivel}
          onChange={(e) => setDisponivel(e.target.checked)}
          disabled={enviando}
          className="size-4 rounded border-input accent-[hsl(var(--primary))]"
        />
        Disponível
      </label>
      {erro && <p className="text-xs text-destructive">{erro}</p>}
      <div className="flex gap-2">
        <Button type="submit" variant="primary" size="sm" disabled={enviando}>
          {enviando && <Loader2 className="animate-spin" aria-hidden />}
          {opcao ? 'Salvar opção' : 'Criar opção'}
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={onCancelar} disabled={enviando}>
          <X aria-hidden />
          Cancelar
        </Button>
      </div>
    </form>
  );
}
