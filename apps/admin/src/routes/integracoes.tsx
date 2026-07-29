import * as React from 'react';
import {
  CheckCircle2,
  Download,
  Loader2,
  Plug,
  RefreshCw,
  Settings2,
  XCircle,
} from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import { useCardapios } from '@/lib/cardapios';
import { mensagemDeErro, type ImportResumo } from '@/lib/publicacao';
import {
  useImportarConector,
  useIntegracoes,
  useSalvarIntegracao,
  useTestarIntegracao,
  type Integracao,
} from '@/lib/integracoes';

/**
 * Integrações (Fase 2) — o GoGeM como API aberta de conectores. Galeria de
 * cards; cada conector guarda credenciais por tenant (segredos mascarados) e,
 * quando suporta, importa o catálogo. Regem é o 1º conector; Open Delivery e
 * outros entram como "em breve". Só gerente+ configura (RBAC no servidor).
 */
export default function IntegracoesPage() {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading, isError } = useIntegracoes();

  return (
    <section className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Integrações</h1>
        <p className="text-sm text-muted-foreground">
          Conecte o GoGeM a outros sistemas. O <strong>Regem</strong> importa o
          catálogo por código PDV e recebe as vendas do totem. Novos conectores
          entram no padrão Open Delivery.
        </p>
      </header>

      {isLoading && (
        <div className="flex justify-center py-16 text-muted-foreground">
          <Loader2 className="size-6 animate-spin" aria-hidden />
        </div>
      )}
      {isError && (
        <p role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
          Não foi possível carregar as integrações.
        </p>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {data?.map((it) => (
          <ConectorCard key={it.tipo} integracao={it} podeEscrever={podeEscrever} />
        ))}
      </div>
    </section>
  );
}

function ConectorCard({
  integracao,
  podeEscrever,
}: {
  integracao: Integracao;
  podeEscrever: boolean;
}) {
  const [aberto, setAberto] = React.useState(false);
  const importar = useImportarConector();
  const { data: cardapios } = useCardapios();
  const [destino, setDestino] = React.useState('');
  const [resumo, setResumo] = React.useState<ImportResumo | null>(null);
  const [erro, setErro] = React.useState<string | null>(null);

  const podeImportar =
    integracao.disponivel && integracao.importaCatalogo && integracao.ativo;
  const multiCardapio = (cardapios?.length ?? 0) > 1;

  async function onImportar() {
    setErro(null);
    setResumo(null);
    try {
      setResumo(
        await importar.mutateAsync({
          tipo: integracao.tipo,
          cardapioId: destino || undefined,
        }),
      );
    } catch (e) {
      setErro(mensagemDeErro(e));
    }
  }

  return (
    <Card className="flex flex-col">
      <CardContent className="flex flex-1 flex-col gap-3 p-5">
        <div className="flex items-start justify-between gap-2">
          <div className="flex size-10 items-center justify-center rounded-lg bg-secondary text-primary">
            <Plug className="size-5" aria-hidden />
          </div>
          <EstadoBadge integracao={integracao} />
        </div>

        <div className="space-y-1">
          <p className="font-display font-semibold">{integracao.nome}</p>
          <p className="text-sm text-muted-foreground">{integracao.descricao}</p>
        </div>

        {integracao.ultimoTeste && (
          <p
            className={`flex items-center gap-1.5 text-xs ${
              integracao.ultimoTeste.ok ? 'text-success' : 'text-destructive'
            }`}
          >
            {integracao.ultimoTeste.ok ? (
              <CheckCircle2 className="size-3.5" aria-hidden />
            ) : (
              <XCircle className="size-3.5" aria-hidden />
            )}
            {integracao.ultimoTeste.detalhe}
          </p>
        )}

        <div className="mt-auto flex flex-wrap gap-2 pt-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setAberto(true)}
            disabled={!integracao.disponivel || !podeEscrever}
          >
            <Settings2 aria-hidden />
            Configurar
          </Button>
          {integracao.importaCatalogo && (
            <>
              {multiCardapio && podeImportar && podeEscrever && (
                <select
                  aria-label="Cardápio de destino da importação"
                  value={destino}
                  onChange={(e) => setDestino(e.target.value)}
                  className="h-9 rounded-md border border-input bg-background px-2 text-xs ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <option value="">Cardápio ativo</option>
                  {cardapios!
                    .filter((c) => !c.ativo)
                    .map((c) => (
                      <option key={c.id} value={c.id}>
                        → {c.nome}
                      </option>
                    ))}
                </select>
              )}
              <Button
                variant="ghost"
                size="sm"
                onClick={onImportar}
                disabled={!podeImportar || importar.isPending || !podeEscrever}
                title={
                  podeImportar
                    ? undefined
                    : 'Configure e ative a integração para importar.'
                }
              >
                {importar.isPending ? (
                  <Loader2 className="animate-spin" aria-hidden />
                ) : (
                  <Download aria-hidden />
                )}
                Importar catálogo
              </Button>
            </>
          )}
        </div>

        {erro && (
          <p role="alert" className="text-xs text-destructive">
            {erro}
          </p>
        )}
        {resumo && <ResumoImport resumo={resumo} />}
      </CardContent>

      {aberto && (
        <ConfigDialog
          integracao={integracao}
          aberto={aberto}
          onFechar={() => setAberto(false)}
        />
      )}
    </Card>
  );
}

function EstadoBadge({ integracao }: { integracao: Integracao }) {
  if (!integracao.disponivel) return <Badge variant="outline">Em breve</Badge>;
  if (integracao.ativo) return <Badge variant="success">Ativo</Badge>;
  if (integracao.configurado) return <Badge>Configurado</Badge>;
  return <Badge variant="outline">Não configurado</Badge>;
}

function ConfigDialog({
  integracao,
  aberto,
  onFechar,
}: {
  integracao: Integracao;
  aberto: boolean;
  onFechar: () => void;
}) {
  const salvar = useSalvarIntegracao();
  const testar = useTestarIntegracao();
  const [valores, setValores] = React.useState<Record<string, string>>({});
  const [ativo, setAtivo] = React.useState(integracao.ativo);
  const [erro, setErro] = React.useState<string | null>(null);
  const teste = testar.data;

  // Campos-segredo começam vazios (não editamos a máscara); os demais vêm
  // preenchidos com o valor guardado.
  React.useEffect(() => {
    const iniciais: Record<string, string> = {};
    for (const c of integracao.campos) iniciais[c.key] = c.secret ? '' : c.valor;
    setValores(iniciais);
    setAtivo(integracao.ativo);
    setErro(null);
  }, [integracao]);

  function set(key: string, v: string) {
    setValores((x) => ({ ...x, [key]: v }));
  }

  async function onSalvar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    // Só envia campos com valor digitado (segredo em branco = mantém).
    const config: Record<string, string> = {};
    for (const c of integracao.campos) {
      const v = valores[c.key] ?? '';
      if (c.secret) {
        if (v.trim()) config[c.key] = v.trim();
      } else {
        config[c.key] = v.trim();
      }
    }
    try {
      await salvar.mutateAsync({ tipo: integracao.tipo, input: { ativo, config } });
      onFechar();
    } catch (err) {
      setErro(mensagemDeErro(err));
    }
  }

  async function onTestar() {
    setErro(null);
    // Salva antes de testar (o teste usa a config guardada).
    const config: Record<string, string> = {};
    for (const c of integracao.campos) {
      const v = valores[c.key] ?? '';
      if (c.secret) {
        if (v.trim()) config[c.key] = v.trim();
      } else {
        config[c.key] = v.trim();
      }
    }
    try {
      await salvar.mutateAsync({ tipo: integracao.tipo, input: { config } });
      await testar.mutateAsync(integracao.tipo);
    } catch (err) {
      setErro(mensagemDeErro(err));
    }
  }

  const ocupado = salvar.isPending || testar.isPending;

  return (
    <Dialog
      aberto={aberto}
      onFechar={onFechar}
      titulo={`Configurar ${integracao.nome}`}
      descricao="Credenciais guardadas por loja. Segredos ficam mascarados."
    >
      <form className="space-y-4" onSubmit={onSalvar} noValidate>
        {integracao.campos.map((c) => (
          <div key={c.key} className="space-y-2">
            <Label htmlFor={`int-${c.key}`}>{c.label}</Label>
            <Input
              id={`int-${c.key}`}
              type={c.secret ? 'password' : c.url ? 'url' : 'text'}
              value={valores[c.key] ?? ''}
              onChange={(e) => set(c.key, e.target.value)}
              placeholder={
                c.secret && c.preenchido ? '•••••••• (guardado)' : c.ajuda
              }
              disabled={ocupado}
              autoComplete="off"
            />
            {c.ajuda && !c.secret && (
              <p className="text-xs text-muted-foreground">{c.ajuda}</p>
            )}
          </div>
        ))}

        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={ativo}
            onChange={(e) => setAtivo(e.target.checked)}
            disabled={ocupado}
            className="size-4 rounded border-input accent-[hsl(var(--primary))]"
          />
          Integração ativa
        </label>

        {teste && (
          <p
            role="status"
            className={`flex items-center gap-1.5 rounded-md px-3 py-2 text-sm ${
              teste.ok
                ? 'bg-success/10 text-success'
                : 'bg-destructive/10 text-destructive'
            }`}
          >
            {teste.ok ? (
              <CheckCircle2 className="size-4" aria-hidden />
            ) : (
              <XCircle className="size-4" aria-hidden />
            )}
            {teste.detalhe}
          </p>
        )}
        {erro && (
          <p role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
            {erro}
          </p>
        )}

        <div className="flex flex-wrap justify-end gap-2 pt-2">
          <Button type="button" variant="ghost" onClick={onTestar} disabled={ocupado}>
            {testar.isPending ? (
              <Loader2 className="animate-spin" aria-hidden />
            ) : (
              <RefreshCw aria-hidden />
            )}
            Testar conexão
          </Button>
          <Button type="submit" variant="primary" disabled={ocupado}>
            {salvar.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Salvar
          </Button>
        </div>
      </form>
    </Dialog>
  );
}

function ResumoImport({ resumo }: { resumo: ImportResumo }) {
  return (
    <div className="rounded-md border border-border bg-secondary/30 px-3 py-2 text-xs">
      <p className="font-medium text-success">Import concluído</p>
      <p className="text-muted-foreground">
        Produtos {resumo.produtos.criados}+/{resumo.produtos.atualizados}~ ·
        Categorias {resumo.categorias.criadas}+/{resumo.categorias.atualizadas}~
        · Opções {resumo.opcoes.criados}+/{resumo.opcoes.atualizados}~
        {resumo.produtos.ignoradosSemCodigo > 0 &&
          ` · ${resumo.produtos.ignoradosSemCodigo} sem código PDV`}
      </p>
      <p className="mt-1 text-muted-foreground">
        Revise em <strong>Catálogo</strong> e publique para o totem receber.
      </p>
    </div>
  );
}
