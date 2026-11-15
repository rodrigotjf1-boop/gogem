import * as React from 'react';
import { Link2, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { mensagemDeErro } from '@/lib/publicacao';
import {
  enderecoDoRegem,
  useConectarPeloRegem,
  useEscolherLojaDoRegem,
  type SituacaoClique,
} from '@/lib/integracoes';

/**
 * "Conectar pelo Regem" (Hub DMS F6, protótipo `clique-gogem.html` do hub): o presidente da
 * empresa autoriza no próprio Regem, escolhendo as lojas do totem, e ninguém copia token. O
 * token colado continua em "Configurar" até o fim da F6.
 *
 * O botão leva o mesmo nome nos dois estados: é o caminho que a mensagem da recusa aponta
 * ("Integrações › Regem › Conectar pelo Regem").
 */
export function ConectarPeloRegem({
  clique,
  podeEscrever,
}: {
  clique: SituacaoClique;
  podeEscrever: boolean;
}) {
  const conectar = useConectarPeloRegem();
  const escolher = useEscolherLojaDoRegem();
  const [indo, setIndo] = React.useState(false);
  const [msg, setMsg] = React.useState<{
    tom: 'erro' | 'ok';
    texto: string;
  } | null>(null);

  async function onConectar() {
    setMsg(null);
    try {
      const { url } = await conectar.mutateAsync();
      if (!enderecoDoRegem(url)) {
        setMsg({
          tom: 'erro',
          texto:
            'O endereço do Regem veio errado. Tente de novo; se repetir, fale com o suporte.',
        });
        return;
      }
      setIndo(true);
      window.location.assign(url);
    } catch (e) {
      setIndo(false);
      setMsg({ tom: 'erro', texto: mensagemDeErro(e) });
    }
  }

  async function onEscolher(lojaId: string) {
    if (!lojaId || lojaId === clique.emUso?.id) return;
    setMsg(null);
    try {
      const s = await escolher.mutateAsync(lojaId);
      const nome = s.emUso?.nome ?? 'a loja escolhida';
      setMsg({
        tom: 'ok',
        texto: `Agora as vendas do totem entram em ${nome}. Importe o catálogo de novo para trazer o cardápio dela.`,
      });
    } catch (e) {
      setMsg({ tom: 'erro', texto: mensagemDeErro(e) });
    }
  }

  const ocupado = conectar.isPending || indo;

  return (
    <div className="space-y-2 rounded-md border border-input p-3">
      {clique.conectado ? (
        <p className="flex items-start gap-1.5 text-xs text-success">
          <Link2 className="mt-0.5 size-3.5 shrink-0" aria-hidden />
          <span>
            Conectado pelo Regem: <strong>{clique.emUso?.nome ?? '—'}</strong>.
            As vendas do totem entram nesta loja.
          </span>
        </p>
      ) : (
        <p className="text-xs text-muted-foreground">
          Você não copia nenhum token: o presidente da empresa autoriza no
          próprio Regem, escolhendo a loja do totem.
        </p>
      )}

      {clique.conectado && clique.lojas.length > 1 && (
        <label className="flex flex-col gap-1 text-xs">
          <span className="font-medium">Loja do Regem em uso</span>
          <select
            value={clique.emUso?.id ?? ''}
            onChange={(e) => void onEscolher(e.target.value)}
            disabled={!podeEscrever || escolher.isPending}
            className="h-9 w-full rounded-md border border-input bg-background px-2 text-xs ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            {clique.lojas.map((l) => (
              <option key={l.id} value={l.id}>
                {l.nome}
              </option>
            ))}
          </select>
        </label>
      )}

      {clique.disponivel && (
        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant={clique.conectado ? 'ghost' : 'outline'}
            size="sm"
            onClick={onConectar}
            disabled={!podeEscrever || ocupado}
          >
            {ocupado ? (
              <Loader2 className="animate-spin" aria-hidden />
            ) : (
              <Link2 aria-hidden />
            )}
            {indo ? 'Indo para o Regem…' : 'Conectar pelo Regem'}
          </Button>
          {!clique.conectado && (
            <span className="text-xs text-muted-foreground">
              Abre a página do Regem. Lá, o presidente vê o que o GoGeM vai ler
              e lançar e confirma com a senha.
            </span>
          )}
        </div>
      )}

      {msg && (
        <p
          role={msg.tom === 'erro' ? 'alert' : 'status'}
          className={`text-xs ${msg.tom === 'erro' ? 'text-destructive' : 'text-muted-foreground'}`}
        >
          {msg.texto}
        </p>
      )}
    </div>
  );
}
