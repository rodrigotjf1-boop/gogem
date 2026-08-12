import * as React from 'react';
import { Loader2, UploadCloud, CheckCircle2, Download } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { mensagemDeErro } from '@/lib/publicacao';
import {
  useReleases,
  usePublicarRelease,
  useWindowsBuilds,
  usePublicarWindows,
} from '@/lib/org-releases';

/**
 * Versões do totem (auto-update) — Console da Distribuição. A organização (DMS)
 * sobe o APK novo; os totens pareados baixam sozinhos na próxima verificação.
 * Auth pela sessão da org (sem token colado).
 */
export default function VersoesPage() {
  const releases = useReleases();
  const publicar = usePublicarRelease();

  const [apk, setApk] = React.useState<File | null>(null);
  const [versionCode, setVersionCode] = React.useState('');
  const [versionName, setVersionName] = React.useState('');
  const [notas, setNotas] = React.useState('');
  const [obrigatorio, setObrigatorio] = React.useState(false);
  const [erro, setErro] = React.useState<string | null>(null);
  const [ok, setOk] = React.useState(false);

  async function onPublicar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    setOk(false);
    if (!apk) return setErro('Selecione o arquivo .apk.');
    const code = Number(versionCode);
    if (!Number.isInteger(code) || code < 1)
      return setErro('versionCode inválido (inteiro do pubspec, ex.: 7).');
    if (!versionName.trim())
      return setErro('Informe o versionName (ex.: 0.5.2).');
    try {
      await publicar.mutateAsync({
        apk,
        versionCode: code,
        versionName: versionName.trim(),
        notas: notas.trim() || undefined,
        obrigatorio,
      });
      setOk(true);
      setApk(null);
      setVersionCode('');
      setVersionName('');
      setNotas('');
      setObrigatorio(false);
    } catch (err) {
      setErro(mensagemDeErro(err));
    }
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div>
        <h1 className="font-display text-2xl font-semibold">Versões do totem</h1>
        <p className="text-sm text-muted-foreground">
          Publique o APK novo — os totens Android pareados baixam e instalam
          sozinhos na próxima verificação. O APK é o mesmo produto para todas as
          lojas.
        </p>
      </div>

      <Card>
        <CardContent className="space-y-4 p-5">
          <form onSubmit={onPublicar} className="space-y-3">
            <div className="space-y-1">
              <Label className="text-xs">Arquivo .apk</Label>
              <input
                type="file"
                accept=".apk,application/vnd.android.package-archive"
                onChange={(e) => setApk(e.target.files?.[0] ?? null)}
                className="block w-full text-sm text-muted-foreground file:mr-3 file:rounded-md file:border-0 file:bg-secondary file:px-3 file:py-2 file:text-sm file:text-foreground"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs">versionCode</Label>
                <Input
                  inputMode="numeric"
                  value={versionCode}
                  onChange={(e) => setVersionCode(e.target.value)}
                  placeholder="ex.: 7"
                />
              </div>
              <div className="space-y-1">
                <Label className="text-xs">versionName</Label>
                <Input
                  value={versionName}
                  onChange={(e) => setVersionName(e.target.value)}
                  placeholder="ex.: 0.5.2"
                />
              </div>
            </div>
            <div className="space-y-1">
              <Label className="text-xs">Notas (opcional)</Label>
              <Input
                value={notas}
                onChange={(e) => setNotas(e.target.value)}
                placeholder="o que mudou nesta versão"
              />
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={obrigatorio}
                onChange={(e) => setObrigatorio(e.target.checked)}
              />
              Atualização obrigatória (força no totem)
            </label>

            {erro && <p className="text-xs text-destructive">{erro}</p>}
            {ok && (
              <p className="flex items-center gap-1.5 text-xs text-success">
                <CheckCircle2 className="size-3.5" aria-hidden /> Versão
                publicada.
              </p>
            )}

            <Button
              type="submit"
              variant="primary"
              disabled={publicar.isPending}
            >
              {publicar.isPending ? (
                <Loader2 className="animate-spin" aria-hidden />
              ) : (
                <UploadCloud aria-hidden />
              )}
              Publicar versão
            </Button>
          </form>

          <div className="space-y-2 border-t border-border pt-3">
            <p className="text-xs font-medium text-muted-foreground">
              Versões publicadas
            </p>
            {releases.isLoading ? (
              <Loader2 className="size-4 animate-spin text-muted-foreground" />
            ) : releases.isError ? (
              <p className="text-xs text-destructive">
                {mensagemDeErro(releases.error)}
              </p>
            ) : !releases.data?.length ? (
              <p className="text-xs text-muted-foreground">
                Nenhuma versão ainda.
              </p>
            ) : (
              <ul className="space-y-1">
                {releases.data.map((r) => (
                  <li
                    key={r.id}
                    className="flex items-center justify-between gap-2 text-sm"
                  >
                    <span>
                      <span className="font-mono">{r.versionName}</span>
                      <span className="text-muted-foreground">
                        {' '}
                        (code {r.versionCode})
                      </span>
                      {r.obrigatorio && (
                        <span className="ml-2 rounded bg-destructive/10 px-1.5 py-0.5 text-xs text-destructive">
                          obrigatória
                        </span>
                      )}
                    </span>
                    {r.ativo ? (
                      <span className="rounded bg-success/10 px-1.5 py-0.5 text-xs text-success">
                        ativa
                      </span>
                    ) : (
                      <span className="text-xs text-muted-foreground">
                        inativa
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </CardContent>
      </Card>

      <SecaoWindows />
    </div>
  );
}

/**
 * Build Windows (totem em PC). Só DOWNLOAD — não há auto-update no Windows: o
 * operador baixa o .zip da pasta Release e segue o tutorial
 * (docs/totem-windows.md no repositório).
 */
function SecaoWindows() {
  const builds = useWindowsBuilds();
  const publicar = usePublicarWindows();
  const [build, setBuild] = React.useState<File | null>(null);
  const [versao, setVersao] = React.useState('');
  const [notas, setNotas] = React.useState('');
  const [erro, setErro] = React.useState<string | null>(null);
  const [ok, setOk] = React.useState(false);

  async function onPublicar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    setOk(false);
    if (!build) return setErro('Selecione o .zip da pasta Release.');
    if (!versao.trim()) return setErro('Informe a versão (ex.: 0.5.17).');
    try {
      await publicar.mutateAsync({
        build,
        versao: versao.trim(),
        notas: notas.trim() || undefined,
      });
      setOk(true);
      setBuild(null);
      setVersao('');
      setNotas('');
    } catch (err) {
      setErro(mensagemDeErro(err));
    }
  }

  return (
    <div className="space-y-3">
      <div>
        <h2 className="font-display text-lg font-semibold">Totem no Windows</h2>
        <p className="text-sm text-muted-foreground">
          Build para PC Windows — <strong>só download</strong> (não há
          auto-update). Suba o <code>.zip</code> da pasta <code>Release</code>; a
          instalação segue o tutorial <code>docs/totem-windows.md</code>.
        </p>
      </div>
      <Card>
        <CardContent className="space-y-4 p-5">
          <form onSubmit={onPublicar} className="space-y-3">
            <div className="space-y-1">
              <Label className="text-xs">Arquivo .zip (pasta Release)</Label>
              <input
                type="file"
                accept=".zip,application/zip"
                onChange={(e) => setBuild(e.target.files?.[0] ?? null)}
                className="block w-full text-sm text-muted-foreground file:mr-3 file:rounded-md file:border-0 file:bg-secondary file:px-3 file:py-2 file:text-sm file:text-foreground"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs">Versão</Label>
                <Input
                  value={versao}
                  onChange={(e) => setVersao(e.target.value)}
                  placeholder="ex.: 0.5.17"
                />
              </div>
              <div className="space-y-1">
                <Label className="text-xs">Notas (opcional)</Label>
                <Input
                  value={notas}
                  onChange={(e) => setNotas(e.target.value)}
                  placeholder="o que mudou"
                />
              </div>
            </div>

            {erro && <p className="text-xs text-destructive">{erro}</p>}
            {ok && (
              <p className="flex items-center gap-1.5 text-xs text-success">
                <CheckCircle2 className="size-3.5" aria-hidden /> Build enviado.
              </p>
            )}

            <Button
              type="submit"
              variant="primary"
              disabled={publicar.isPending}
            >
              {publicar.isPending ? (
                <Loader2 className="animate-spin" aria-hidden />
              ) : (
                <UploadCloud aria-hidden />
              )}
              Enviar build Windows
            </Button>
          </form>

          <div className="space-y-2 border-t border-border pt-3">
            <p className="text-xs font-medium text-muted-foreground">
              Builds disponíveis
            </p>
            {builds.isLoading ? (
              <Loader2 className="size-4 animate-spin text-muted-foreground" />
            ) : builds.isError ? (
              <p className="text-xs text-destructive">
                {mensagemDeErro(builds.error)}
              </p>
            ) : !builds.data?.length ? (
              <p className="text-xs text-muted-foreground">
                Nenhum build Windows ainda.
              </p>
            ) : (
              <ul className="space-y-1">
                {builds.data.map((b) => (
                  <li
                    key={b.id}
                    className="flex items-center justify-between gap-2 text-sm"
                  >
                    <span className="font-mono">{b.versao}</span>
                    <a
                      href={b.url}
                      target="_blank"
                      rel="noreferrer"
                      className="flex items-center gap-1 text-primary hover:underline"
                    >
                      <Download className="size-3.5" aria-hidden /> baixar .zip
                    </a>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
