import * as React from 'react';
import { Loader2, UploadCloud, CheckCircle2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { mensagemDeErro } from '@/lib/publicacao';
import {
  getReleaseToken,
  setReleaseToken,
  useReleases,
  usePublicarRelease,
} from '@/lib/kiosk-release';

/**
 * Atualizações do totem (auto-update). O dono (DMS) sobe o APK novo; os totens
 * pareados baixam sozinhos na próxima verificação. Protegido pelo token de
 * release (não é ação de lojista) — guardado no navegador.
 */
export function AtualizacoesTotem() {
  const [token, setToken] = React.useState(getReleaseToken());
  const releases = useReleases(token);
  const publicar = usePublicarRelease();

  const [apk, setApk] = React.useState<File | null>(null);
  const [versionCode, setVersionCode] = React.useState('');
  const [versionName, setVersionName] = React.useState('');
  const [notas, setNotas] = React.useState('');
  const [obrigatorio, setObrigatorio] = React.useState(false);
  const [erro, setErro] = React.useState<string | null>(null);
  const [ok, setOk] = React.useState(false);

  function salvarToken(v: string) {
    setToken(v);
    setReleaseToken(v);
  }

  async function onPublicar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    setOk(false);
    if (!apk) return setErro('Selecione o arquivo .apk.');
    const code = Number(versionCode);
    if (!Number.isInteger(code) || code < 1)
      return setErro('versionCode inválido (inteiro do pubspec, ex.: 7).');
    if (!versionName.trim()) return setErro('Informe o versionName (ex.: 0.5.2).');
    try {
      await publicar.mutateAsync({
        apk,
        versionCode: code,
        versionName: versionName.trim(),
        notas: notas.trim() || undefined,
        obrigatorio,
        token,
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
    <Card>
      <CardContent className="space-y-4 p-5">
        <div className="space-y-1">
          <h2 className="font-display font-semibold">Atualizações do totem</h2>
          <p className="text-sm text-muted-foreground">
            Suba o APK novo — os totens pareados baixam e instalam sozinhos na
            próxima verificação. Ação do DMS (protegida por token de release).
          </p>
        </div>

        <div className="space-y-1">
          <Label className="text-xs">Token de release (KIOSK_RELEASE_TOKEN)</Label>
          <Input
            type="password"
            value={token}
            onChange={(e) => salvarToken(e.target.value)}
            placeholder="segredo definido na API"
            autoComplete="off"
          />
        </div>

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
              <CheckCircle2 className="size-3.5" aria-hidden /> Release publicada.
            </p>
          )}

          <Button type="submit" variant="primary" disabled={publicar.isPending}>
            {publicar.isPending ? (
              <Loader2 className="animate-spin" aria-hidden />
            ) : (
              <UploadCloud aria-hidden />
            )}
            Publicar release
          </Button>
        </form>

        {/* Histórico */}
        {token && (
          <div className="space-y-2 border-t border-border pt-3">
            <p className="text-xs font-medium text-muted-foreground">
              Releases publicadas
            </p>
            {releases.isLoading ? (
              <Loader2 className="size-4 animate-spin text-muted-foreground" />
            ) : releases.isError ? (
              <p className="text-xs text-destructive">
                {mensagemDeErro(releases.error)}
              </p>
            ) : !releases.data?.length ? (
              <p className="text-xs text-muted-foreground">Nenhuma release ainda.</p>
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
                      <span className="text-xs text-muted-foreground">inativa</span>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
