import * as React from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle2, Loader2, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { mensagemDeErro } from '@/lib/publicacao';
import { useConcluirClique } from '@/lib/integracoes';

type Estado =
  | { fase: 'concluindo' }
  | { fase: 'conectado'; loja: string | null; lojas: number; avisos: string }
  | { fase: 'recusado' }
  | { fase: 'erro'; mensagem: string };

/**
 * A volta do "Conectar pelo Regem" (o endereço cadastrado na ficha do GoGeM no Regem). O Regem
 * manda o navegador para cá com o código, o `state` e o `iss`; a página repassa ao servidor tal
 * como veio (é ele que confere tudo e troca o código pela ligação de cada loja) e tira o código
 * da barra de endereço. Dentro do `RequireAuth`: sem sessão, a pessoa entra e volta para cá com
 * a busca (o login devolve `pathname + search`).
 */
export default function VoltaDoRegemPage() {
  const concluir = useConcluirClique();
  const [estado, setEstado] = React.useState<Estado>({ fase: 'concluindo' });
  const feito = React.useRef(false);

  React.useEffect(() => {
    // Uma vez só: o código vale uma vez (o modo estrito do React roda o efeito duas vezes).
    if (feito.current) return;
    feito.current = true;
    const q = new URLSearchParams(window.location.search);
    const campo = (nome: string) => q.get(nome) ?? undefined;
    const volta = {
      code: campo('code'),
      state: campo('state'),
      iss: campo('iss'),
      error: campo('error'),
    };
    window.history.replaceState(null, '', window.location.pathname);
    concluir.mutateAsync(volta).then(
      (r) =>
        setEstado(
          r.situacao === 'conectado'
            ? {
                fase: 'conectado',
                loja: r.clique.emUso?.nome ?? null,
                lojas: r.clique.lojas.length,
                avisos: r.avisos,
              }
            : { fase: 'recusado' },
        ),
      (e) => setEstado({ fase: 'erro', mensagem: mensagemDeErro(e) }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const titulo =
    estado.fase === 'concluindo'
      ? 'Concluindo a conexão…'
      : estado.fase === 'conectado'
        ? 'Pronto: conectado pelo Regem'
        : estado.fase === 'recusado'
          ? 'Nada foi ligado'
          : 'Não deu para concluir';

  return (
    <section className="mx-auto max-w-2xl space-y-6">
      <header className="space-y-1">
        <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
          Integrações
        </p>
        <h1 className="text-2xl font-bold">Conectar pelo Regem</h1>
      </header>

      <Card>
        <CardContent className="space-y-4 p-5">
          <h2 className="flex items-center gap-2 font-display text-lg font-semibold">
            {estado.fase === 'concluindo' && (
              <Loader2
                className="size-5 animate-spin text-primary"
                aria-hidden
              />
            )}
            {estado.fase === 'conectado' && (
              <CheckCircle2 className="size-5 text-success" aria-hidden />
            )}
            {(estado.fase === 'recusado' || estado.fase === 'erro') && (
              <XCircle className="size-5 text-destructive" aria-hidden />
            )}
            {titulo}
          </h2>

          {estado.fase === 'concluindo' && (
            <p className="text-sm" role="status">
              Conferindo a autorização com o Regem…
            </p>
          )}
          {estado.fase === 'conectado' && (
            <div className="max-w-prose space-y-2 text-sm leading-relaxed">
              <p>
                As vendas do totem entram em{' '}
                <strong>{estado.loja ?? 'a loja escolhida'}</strong>.{' '}
                {estado.lojas > 1
                  ? `Você ligou ${estado.lojas} lojas: a loja em uso se troca no cartão do Regem, em Integrações.`
                  : null}
              </p>
              <p>
                Para trazer o cardápio dela, use “Importar catálogo” no cartão
                do Regem.
              </p>
              {estado.avisos && (
                <p className="text-muted-foreground">{estado.avisos}</p>
              )}
            </div>
          )}
          {estado.fase === 'recusado' && (
            <p className="max-w-prose text-sm leading-relaxed">
              O presidente da empresa não autorizou no Regem. Nada mudou aqui;
              quando quiser, comece de novo pelo botão “Conectar pelo Regem”.
            </p>
          )}
          {estado.fase === 'erro' && (
            <p
              role="alert"
              className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
            >
              {estado.mensagem}
            </p>
          )}
          {estado.fase !== 'concluindo' && (
            <Button
              asChild
              variant={estado.fase === 'conectado' ? 'default' : 'outline'}
            >
              <Link to="/integracoes">Ver a integração</Link>
            </Button>
          )}
        </CardContent>
      </Card>
    </section>
  );
}
