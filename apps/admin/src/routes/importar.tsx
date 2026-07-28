import * as React from 'react';
import { Download, Loader2, RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { usePodeEscrever } from '@/auth/auth-context';
import {
  mensagemDeErro,
  useImportarRegem,
  type ImportResumo,
} from '@/lib/publicacao';

/**
 * Importar do Regem — puxa o catálogo do ERP Regem (por `codigo_pdv`) para o
 * rascunho do GoGeM. Aditivo: cria o que falta e atualiza o que já existe;
 * nunca apaga. Só gerente+ dispara (RBAC no servidor).
 */
export default function ImportarPage() {
  const podeEscrever = usePodeEscrever();
  const importar = useImportarRegem();
  const [resumo, setResumo] = React.useState<ImportResumo | null>(null);
  const [erro, setErro] = React.useState<string | null>(null);

  async function executar() {
    setErro(null);
    setResumo(null);
    try {
      const r = await importar.mutateAsync();
      setResumo(r);
    } catch (e) {
      setErro(mensagemDeErro(e));
    }
  }

  return (
    <section className="mx-auto max-w-3xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Importar do Regem</h1>
        <p className="text-sm text-muted-foreground">
          Puxa categorias, produtos e complementos do Regem para o rascunho do
          cardápio, casando pelo código PDV. É aditivo: cria o que falta e
          atualiza o que já existe — nunca apaga.
        </p>
      </header>

      <Card>
        <CardContent className="flex flex-col items-start gap-4 p-6">
          <div className="flex size-12 items-center justify-center rounded-full bg-secondary text-primary">
            <Download className="size-6" aria-hidden />
          </div>
          <div className="space-y-1">
            <p className="font-display font-semibold">
              Sincronizar catálogo do ERP
            </p>
            <p className="text-sm text-muted-foreground">
              Depois de importar, revise em <strong>Catálogo</strong> e publique
              uma nova versão para o totem receber.
            </p>
          </div>

          {podeEscrever ? (
            <Button
              variant="primary"
              onClick={executar}
              disabled={importar.isPending}
            >
              {importar.isPending ? (
                <Loader2 className="animate-spin" aria-hidden />
              ) : (
                <RefreshCw aria-hidden />
              )}
              {importar.isPending ? 'Importando…' : 'Importar do Regem'}
            </Button>
          ) : (
            <p className="text-sm text-muted-foreground">
              Apenas gerentes ou acima podem importar.
            </p>
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

      {resumo && <ResumoImport resumo={resumo} />}
    </section>
  );
}

function ResumoImport({ resumo }: { resumo: ImportResumo }) {
  const linhas = [
    {
      rotulo: 'Categorias',
      criados: resumo.categorias.criadas,
      atualizados: resumo.categorias.atualizadas,
    },
    {
      rotulo: 'Produtos',
      criados: resumo.produtos.criados,
      atualizados: resumo.produtos.atualizados,
    },
    {
      rotulo: 'Grupos de complemento',
      criados: resumo.grupos.criados,
      atualizados: resumo.grupos.atualizados,
    },
    {
      rotulo: 'Opções',
      criados: resumo.opcoes.criados,
      atualizados: resumo.opcoes.atualizados,
    },
  ];

  return (
    <Card>
      <CardContent className="space-y-4 p-6">
        <div className="flex items-center gap-2">
          <span className="inline-flex size-6 items-center justify-center rounded-full bg-success/15 text-success">
            ✓
          </span>
          <p className="font-display font-semibold">Import concluído</p>
        </div>

        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <caption className="sr-only">Resumo do import do Regem</caption>
            <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Item</th>
                <th className="px-4 py-2 text-right font-medium">Criados</th>
                <th className="px-4 py-2 text-right font-medium">Atualizados</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {linhas.map((l) => (
                <tr key={l.rotulo}>
                  <td className="px-4 py-2 font-medium">{l.rotulo}</td>
                  <td className="px-4 py-2 text-right font-mono">{l.criados}</td>
                  <td className="px-4 py-2 text-right font-mono">
                    {l.atualizados}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {resumo.produtos.ignoradosSemCodigo > 0 && (
          <p className="text-sm text-muted-foreground">
            {resumo.produtos.ignoradosSemCodigo} produto(s) do Regem foram
            ignorados por não terem código PDV.
          </p>
        )}
      </CardContent>
    </Card>
  );
}
