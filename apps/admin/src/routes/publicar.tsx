import * as React from 'react';
import { CheckCircle2, Loader2, UploadCloud } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { usePodeEscrever } from '@/auth/auth-context';
import {
  mensagemDeErro,
  usePublicar,
  useVersoes,
  type PublicarResultado,
} from '@/lib/publicacao';

/** Formata ISO → data/hora pt-BR curta. */
function formatarData(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Publicar — congela o rascunho atual do catálogo numa nova versão imutável
 * (`menu_versions`). O totem sincroniza por versão. Publicar: gerente+.
 */
export default function PublicarPage() {
  const podeEscrever = usePodeEscrever();
  const versoes = useVersoes();
  const publicar = usePublicar();
  const [resultado, setResultado] = React.useState<PublicarResultado | null>(
    null,
  );
  const [erro, setErro] = React.useState<string | null>(null);

  async function executar() {
    setErro(null);
    setResultado(null);
    try {
      const r = await publicar.mutateAsync();
      setResultado(r);
    } catch (e) {
      setErro(mensagemDeErro(e));
    }
  }

  const lista = versoes.data ?? [];
  const versaoAtual = lista[0]?.versao;

  return (
    <section className="mx-auto max-w-3xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Publicar</h1>
        <p className="text-sm text-muted-foreground">
          Congela o rascunho atual do cardápio numa nova versão imutável. Os
          totens sincronizam pela versão — só o que está publicado chega neles.
        </p>
      </header>

      <Card>
        <CardContent className="flex flex-col items-start gap-4 p-6">
          <div className="flex size-12 items-center justify-center rounded-full bg-secondary text-primary">
            <UploadCloud className="size-6" aria-hidden />
          </div>
          <div className="space-y-1">
            <p className="font-display font-semibold">
              {versaoAtual
                ? `Versão publicada atual: v${versaoAtual}`
                : 'Nenhuma versão publicada ainda'}
            </p>
            <p className="text-sm text-muted-foreground">
              Publique depois de ajustar o catálogo (ou importar do Regem).
            </p>
          </div>

          {podeEscrever ? (
            <Button
              variant="primary"
              onClick={executar}
              disabled={publicar.isPending}
            >
              {publicar.isPending ? (
                <Loader2 className="animate-spin" aria-hidden />
              ) : (
                <UploadCloud aria-hidden />
              )}
              {publicar.isPending ? 'Publicando…' : 'Publicar nova versão'}
            </Button>
          ) : (
            <p className="text-sm text-muted-foreground">
              Apenas gerentes ou acima podem publicar.
            </p>
          )}

          {resultado && (
            <div
              role="status"
              className="flex w-full items-center gap-3 rounded-md bg-success/10 px-3 py-2 text-sm text-success"
            >
              <CheckCircle2 className="size-5 shrink-0" aria-hidden />
              <span>
                Versão <strong>v{resultado.versao}</strong> publicada —{' '}
                {resultado.totais.produtos} produto(s), {resultado.totais.categorias}{' '}
                categoria(s).
              </span>
            </div>
          )}

          {erro && (
            <p
              role="alert"
              className="w-full rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
            >
              {erro}
            </p>
          )}
        </CardContent>
      </Card>

      <section className="space-y-3">
        <h2 className="font-display text-lg font-semibold">Histórico de versões</h2>

        {versoes.isLoading && (
          <div
            className="flex items-center gap-2 py-6 text-sm text-muted-foreground"
            role="status"
          >
            <Loader2 className="size-4 animate-spin" aria-hidden />
            Carregando versões…
          </div>
        )}

        {versoes.isError && (
          <div className="rounded-lg border border-border bg-card p-6 text-sm">
            <p className="text-destructive">Não foi possível carregar.</p>
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => versoes.refetch()}
            >
              Tentar novamente
            </Button>
          </div>
        )}

        {versoes.data && lista.length === 0 && (
          <div className="rounded-lg border border-dashed border-border py-12 text-center text-sm text-muted-foreground">
            Nenhuma versão publicada ainda. Publique a primeira acima.
          </div>
        )}

        {lista.length > 0 && (
          <div className="overflow-x-auto rounded-lg border border-border">
            <table className="w-full text-sm">
              <caption className="sr-only">Versões publicadas do catálogo</caption>
              <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
                <tr>
                  <th className="px-4 py-2 font-medium">Versão</th>
                  <th className="px-4 py-2 font-medium">Publicada em</th>
                  <th className="px-4 py-2 font-medium">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {lista.map((v) => (
                  <tr key={v.id} className="hover:bg-secondary/30">
                    <td className="px-4 py-2 font-mono font-medium">v{v.versao}</td>
                    <td className="px-4 py-2 text-muted-foreground">
                      {formatarData(v.publishedAt)}
                    </td>
                    <td className="px-4 py-2">
                      {v.versao === versaoAtual ? (
                        <Badge variant="success">No ar</Badge>
                      ) : (
                        <Badge variant="muted">Anterior</Badge>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </section>
  );
}
