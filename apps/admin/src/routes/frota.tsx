import * as React from 'react';
import { Loader2, Plus, Radio, RotateCcw, Ban } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import {
  codigoExpirado,
  useCriarDispositivo,
  useDispositivos,
  useReparear,
  useRevogar,
  type CodigoEmitido,
  type Dispositivo,
} from '@/lib/frota';

/** Frota — cadastro e pareamento dos totens (device token, sem JWT de 12h). */
export default function FrotaPage() {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading, isError, refetch } = useDispositivos();

  const [novoAberto, setNovoAberto] = React.useState(false);
  const [codigo, setCodigo] = React.useState<CodigoEmitido | null>(null);
  const [removendo, setRemovendo] = React.useState<Dispositivo | undefined>();

  const criar = useCriarDispositivo();
  const reparear = useReparear();
  const revogar = useRevogar();

  return (
    <section className="mx-auto max-w-4xl space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-1">
          <h1 className="text-2xl font-bold">Frota</h1>
          <p className="text-sm text-muted-foreground">
            Cadastre cada totem e pareie por código (6 dígitos, 15 min). O totem
            troca o código por um token próprio — sem depender de login.
          </p>
        </div>
        {podeEscrever && (
          <Button variant="primary" size="sm" onClick={() => setNovoAberto(true)}>
            <Plus aria-hidden />
            Novo totem
          </Button>
        )}
      </header>

      {isLoading && (
        <div className="flex items-center gap-2 py-10 text-sm text-muted-foreground" role="status">
          <Loader2 className="size-4 animate-spin" aria-hidden />
          Carregando totens…
        </div>
      )}

      {isError && (
        <div className="rounded-lg border border-border bg-card p-6 text-sm">
          <p className="text-destructive">Não foi possível carregar.</p>
          <Button variant="outline" size="sm" className="mt-3" onClick={() => refetch()}>
            Tentar novamente
          </Button>
        </div>
      )}

      {data && data.length === 0 && (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center">
          <div className="flex size-12 items-center justify-center rounded-full bg-secondary text-primary">
            <Radio className="size-5" aria-hidden />
          </div>
          <p className="font-display font-semibold">Nenhum totem cadastrado</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            Cadastre o primeiro totem e use o código para parear no aparelho.
          </p>
          {podeEscrever && (
            <Button variant="primary" size="sm" onClick={() => setNovoAberto(true)}>
              <Plus aria-hidden />
              Novo totem
            </Button>
          )}
        </div>
      )}

      {data && data.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <caption className="sr-only">Totens da frota</caption>
            <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Totem</th>
                <th className="px-4 py-2 font-medium">Status</th>
                <th className="px-4 py-2 font-medium">Pareamento</th>
                {podeEscrever && <th className="px-4 py-2 text-right font-medium">Ações</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data.map((d) => (
                <tr key={d.id} className="hover:bg-secondary/30">
                  <td className="px-4 py-2">
                    <div className="font-medium">{d.nome}</div>
                    <div className="text-xs text-muted-foreground">{d.tipo}</div>
                  </td>
                  <td className="px-4 py-2">
                    {!d.ativo ? (
                      <Badge variant="muted">Revogado</Badge>
                    ) : d.pareado ? (
                      <Badge variant="success">Pareado</Badge>
                    ) : (
                      <Badge variant="outline">Aguardando</Badge>
                    )}
                  </td>
                  <td className="px-4 py-2">
                    {d.ativo && !d.pareado ? (
                      d.codigoPareamento && !codigoExpirado(d.codigoExpiraEm) ? (
                        <span className="font-mono text-base font-semibold tracking-widest">
                          {d.codigoPareamento}
                        </span>
                      ) : (
                        <span className="text-xs text-muted-foreground">
                          código expirado — use “reparear”
                        </span>
                      )
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </td>
                  {podeEscrever && (
                    <td className="px-4 py-2">
                      <div className="flex justify-end gap-1">
                        {d.ativo && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={async () => {
                              const r = await reparear.mutateAsync(d.id);
                              setCodigo(r);
                            }}
                            disabled={reparear.isPending}
                          >
                            <RotateCcw className="size-4" aria-hidden />
                            Reparear
                          </Button>
                        )}
                        {d.ativo && (
                          <Button
                            variant="ghost"
                            size="sm"
                            aria-label={`Revogar ${d.nome}`}
                            onClick={() => setRemovendo(d)}
                          >
                            <Ban className="size-4 text-destructive" aria-hidden />
                          </Button>
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <NovoTotemDialog
        aberto={novoAberto}
        onFechar={() => setNovoAberto(false)}
        onCriado={(c) => {
          setNovoAberto(false);
          setCodigo(c);
        }}
        criar={criar}
      />

      <CodigoDialog codigo={codigo} onFechar={() => setCodigo(null)} />

      <ConfirmDialog
        aberto={Boolean(removendo)}
        titulo="Revogar totem"
        descricao={
          removendo
            ? `Revogar “${removendo.nome}”? O token dele para de valer na hora.`
            : ''
        }
        rotuloConfirmar="Revogar"
        onConfirmar={async () => {
          if (removendo) await revogar.mutateAsync(removendo.id);
        }}
        onFechar={() => setRemovendo(undefined)}
      />
    </section>
  );
}

function NovoTotemDialog({
  aberto,
  onFechar,
  onCriado,
  criar,
}: {
  aberto: boolean;
  onFechar: () => void;
  onCriado: (c: CodigoEmitido) => void;
  criar: ReturnType<typeof useCriarDispositivo>;
}) {
  const [nome, setNome] = React.useState('');
  const [erro, setErro] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (aberto) {
      setNome('');
      setErro(null);
    }
  }, [aberto]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (nome.trim().length === 0) {
      setErro('Informe um nome para o totem.');
      return;
    }
    try {
      const c = await criar.mutateAsync({ nome: nome.trim() });
      onCriado(c);
    } catch {
      setErro('Não foi possível cadastrar. Tente novamente.');
    }
  }

  return (
    <Dialog aberto={aberto} onFechar={onFechar} titulo="Novo totem" descricao="Dê um nome; geramos o código de pareamento.">
      <form className="space-y-4" onSubmit={onSubmit} noValidate>
        <div className="space-y-2">
          <Label htmlFor="totem-nome">Nome do totem</Label>
          <Input
            id="totem-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="Totem entrada"
            disabled={criar.isPending}
            autoFocus
          />
          {erro && <p className="text-xs text-destructive">{erro}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={onFechar} disabled={criar.isPending}>
            Cancelar
          </Button>
          <Button type="submit" variant="primary" disabled={criar.isPending}>
            {criar.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Cadastrar
          </Button>
        </div>
      </form>
    </Dialog>
  );
}

function CodigoDialog({
  codigo,
  onFechar,
}: {
  codigo: CodigoEmitido | null;
  onFechar: () => void;
}) {
  return (
    <Dialog
      aberto={Boolean(codigo)}
      onFechar={onFechar}
      titulo="Código de pareamento"
      descricao="Digite este código no totem (menu de pareamento). Vale 15 minutos e some depois."
      larguraClasse="max-w-md"
    >
      {codigo && (
        <div className="space-y-4 text-center">
          <p className="text-sm text-muted-foreground">{codigo.nome}</p>
          <p
            className="font-mono text-5xl font-bold tracking-[0.3em] text-primary"
            aria-label={`Código ${codigo.codigoPareamento.split('').join(' ')}`}
          >
            {codigo.codigoPareamento}
          </p>
          <p className="text-xs text-muted-foreground">
            Expira em {new Date(codigo.codigoExpiraEm).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}.
          </p>
          <Button variant="primary" className="w-full" onClick={onFechar}>
            Fechar
          </Button>
        </div>
      )}
    </Dialog>
  );
}
