import * as React from 'react';
import { Ban, Copy, KeyRound, Loader2, Plug, Plus } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import {
  OD_ESCOPOS,
  useCriarOdApp,
  useOdApps,
  useRevogarOdApp,
  type OdApp,
  type OdAppCriado,
} from '@/lib/open-delivery';

/**
 * Integrações → Open Delivery: apps parceiros que consomem a API pública da loja
 * (`/open-delivery/v1`). O clientSecret é mostrado UMA vez na criação.
 */
export default function OpenDeliveryPage() {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading, isError, refetch } = useOdApps();
  const [novo, setNovo] = React.useState(false);
  const [criado, setCriado] = React.useState<OdAppCriado | null>(null);
  const [revogando, setRevogando] = React.useState<OdApp | undefined>();
  const revogar = useRevogarOdApp();

  return (
    <section className="mx-auto max-w-4xl space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-1">
          <h1 className="text-2xl font-bold">Open Delivery</h1>
          <p className="max-w-2xl text-sm text-muted-foreground">
            Apps de parceiros que integram à sua loja pela API pública
            (cardápio, pedidos e eventos). Cada app recebe um par
            clientId/clientSecret — o segredo aparece só na criação.
          </p>
        </div>
        {podeEscrever && (
          <Button variant="primary" size="sm" onClick={() => setNovo(true)}>
            <Plus aria-hidden />
            Novo app
          </Button>
        )}
      </header>

      {isLoading && (
        <div className="flex items-center gap-2 py-10 text-sm text-muted-foreground" role="status">
          <Loader2 className="size-4 animate-spin" aria-hidden />
          Carregando…
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
            <Plug className="size-5" aria-hidden />
          </div>
          <p className="font-display font-semibold">Nenhum app cadastrado</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            Crie um app para um parceiro integrar à sua loja no padrão Open
            Delivery.
          </p>
        </div>
      )}

      {data && data.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <caption className="sr-only">Apps Open Delivery</caption>
            <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Nome</th>
                <th className="px-4 py-2 font-medium">clientId</th>
                <th className="px-4 py-2 font-medium">Escopos</th>
                <th className="px-4 py-2 font-medium">Status</th>
                {podeEscrever && <th className="px-4 py-2 text-right font-medium">Ações</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data.map((a) => (
                <tr key={a.id} className="hover:bg-secondary/30">
                  <td className="px-4 py-2 font-medium">{a.nome}</td>
                  <td className="px-4 py-2 font-mono text-xs">{a.clientId}</td>
                  <td className="px-4 py-2">
                    <div className="flex flex-wrap gap-1">
                      {a.escopos.map((e) => (
                        <Badge key={e} variant="outline">
                          {e}
                        </Badge>
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-2">
                    <Badge variant={a.ativo ? 'success' : 'muted'}>
                      {a.ativo ? 'Ativo' : 'Revogado'}
                    </Badge>
                  </td>
                  {podeEscrever && (
                    <td className="px-4 py-2 text-right">
                      {a.ativo && (
                        <Button
                          variant="ghost"
                          size="sm"
                          aria-label={`Revogar ${a.nome}`}
                          onClick={() => setRevogando(a)}
                        >
                          <Ban className="size-4 text-destructive" aria-hidden />
                          Revogar
                        </Button>
                      )}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <NovoAppDialog
        aberto={novo}
        onFechar={() => setNovo(false)}
        onCriado={(c) => {
          setNovo(false);
          setCriado(c);
        }}
      />
      <SegredoDialog app={criado} onFechar={() => setCriado(null)} />
      <ConfirmDialog
        aberto={Boolean(revogando)}
        titulo="Revogar app"
        descricao={
          revogando
            ? `Revogar “${revogando.nome}”? Os tokens dele param de valer.`
            : ''
        }
        rotuloConfirmar="Revogar"
        onConfirmar={async () => {
          if (revogando) await revogar.mutateAsync(revogando.id);
        }}
        onFechar={() => setRevogando(undefined)}
      />
    </section>
  );
}

function NovoAppDialog({
  aberto,
  onFechar,
  onCriado,
}: {
  aberto: boolean;
  onFechar: () => void;
  onCriado: (c: OdAppCriado) => void;
}) {
  const criar = useCriarOdApp();
  const [nome, setNome] = React.useState('');
  const [escopos, setEscopos] = React.useState<string[]>([
    'catalog:read',
    'orders:write',
  ]);
  const [erro, setErro] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (aberto) {
      setNome('');
      setEscopos(['catalog:read', 'orders:write']);
      setErro(null);
    }
  }, [aberto]);

  function alternar(e: string) {
    setEscopos((cur) =>
      cur.includes(e) ? cur.filter((x) => x !== e) : [...cur, e],
    );
  }

  async function onSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    if (nome.trim().length < 2) {
      setErro('Informe um nome.');
      return;
    }
    try {
      const c = await criar.mutateAsync({ nome: nome.trim(), escopos });
      onCriado(c);
    } catch {
      setErro('Não foi possível criar. Tente novamente.');
    }
  }

  return (
    <Dialog aberto={aberto} onFechar={onFechar} titulo="Novo app Open Delivery" descricao="Dê um nome e escolha os escopos. Geramos o clientId/clientSecret.">
      <form className="space-y-4" onSubmit={onSubmit} noValidate>
        <div className="space-y-2">
          <Label htmlFor="od-nome">Nome do parceiro</Label>
          <Input
            id="od-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="iFood, ERP do cliente…"
            disabled={criar.isPending}
            autoFocus
          />
        </div>
        <div className="space-y-2">
          <Label>Escopos</Label>
          <div className="flex flex-wrap gap-2">
            {OD_ESCOPOS.map((e) => {
              const on = escopos.includes(e);
              return (
                <button
                  key={e}
                  type="button"
                  aria-pressed={on}
                  onClick={() => alternar(e)}
                  className={
                    'rounded-full border px-3 py-1 text-xs font-medium transition-colors ' +
                    (on
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border text-muted-foreground')
                  }
                >
                  {e}
                </button>
              );
            })}
          </div>
        </div>
        {erro && <p className="text-xs text-destructive">{erro}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={onFechar} disabled={criar.isPending}>
            Cancelar
          </Button>
          <Button type="submit" variant="primary" disabled={criar.isPending}>
            {criar.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Criar app
          </Button>
        </div>
      </form>
    </Dialog>
  );
}

function SegredoDialog({
  app,
  onFechar,
}: {
  app: OdAppCriado | null;
  onFechar: () => void;
}) {
  const [copiado, setCopiado] = React.useState<string | null>(null);
  function copiar(rotulo: string, valor: string) {
    void navigator.clipboard?.writeText(valor);
    setCopiado(rotulo);
    setTimeout(() => setCopiado(null), 1500);
  }
  return (
    <Dialog
      aberto={Boolean(app)}
      onFechar={onFechar}
      titulo="Credenciais do app"
      descricao="Guarde o clientSecret agora — ele NÃO será mostrado de novo."
      larguraClasse="max-w-lg"
    >
      {app && (
        <div className="space-y-4">
          <Credencial rotulo="clientId" valor={app.clientId} copiado={copiado} onCopiar={copiar} />
          <Credencial rotulo="clientSecret" valor={app.clientSecret} copiado={copiado} onCopiar={copiar} destaque />
          <div className="flex items-start gap-2 rounded-md border border-primary/40 bg-primary/5 p-3 text-xs text-muted-foreground">
            <KeyRound className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden />
            <span>
              Envie estas credenciais ao parceiro por um canal seguro. Ele troca
              por um token em <code>POST /open-delivery/v1/oauth/token</code>.
            </span>
          </div>
          <div className="flex justify-end">
            <Button variant="primary" onClick={onFechar}>
              Guardei, fechar
            </Button>
          </div>
        </div>
      )}
    </Dialog>
  );
}

function Credencial({
  rotulo,
  valor,
  copiado,
  onCopiar,
  destaque,
}: {
  rotulo: string;
  valor: string;
  copiado: string | null;
  onCopiar: (r: string, v: string) => void;
  destaque?: boolean;
}) {
  return (
    <div className="space-y-1">
      <Label>{rotulo}</Label>
      <div className="flex items-center gap-2">
        <code
          className={
            'flex-1 overflow-x-auto rounded-md border border-border px-3 py-2 font-mono text-xs ' +
            (destaque ? 'bg-secondary text-foreground' : '')
          }
        >
          {valor}
        </code>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => onCopiar(rotulo, valor)}
        >
          <Copy className="size-4" aria-hidden />
          {copiado === rotulo ? 'Copiado' : 'Copiar'}
        </Button>
      </div>
    </div>
  );
}
