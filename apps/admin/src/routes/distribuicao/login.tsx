import * as React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Loader2 } from 'lucide-react';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useOrgAuth } from '@/auth/org-auth-context';

const schema = z.object({
  email: z.string().email('Informe um e-mail válido'),
  senha: z.string().min(1, 'Informe a senha'),
});

type Campo = 'email' | 'senha';

/** Login do Console da Distribuição (organização/DMS). Sem cadastro público. */
export default function OrgLoginPage() {
  const { login } = useOrgAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const destino =
    (location.state as { from?: { pathname?: string } } | null)?.from
      ?.pathname ?? '/distribuicao';

  const [email, setEmail] = React.useState('');
  const [senha, setSenha] = React.useState('');
  const [erros, setErros] = React.useState<Partial<Record<Campo, string>>>({});
  const [erroGeral, setErroGeral] = React.useState<string | null>(null);
  const [enviando, setEnviando] = React.useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErroGeral(null);
    const parsed = schema.safeParse({ email, senha });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setErros({ email: f.email?.[0], senha: f.senha?.[0] });
      return;
    }
    setErros({});
    setEnviando(true);
    try {
      await login(parsed.data.email, parsed.data.senha);
      navigate(destino, { replace: true });
    } catch (err) {
      setErroGeral(
        err instanceof Error ? err.message : 'E-mail ou senha inválidos',
      );
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <CardTitle className="pt-2">Console da Distribuição</CardTitle>
          <CardDescription>Acesso restrito · organização DMS</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={onSubmit} noValidate>
            <div className="space-y-2">
              <Label htmlFor="org-email">E-mail</Label>
              <Input
                id="org-email"
                type="email"
                autoComplete="username"
                placeholder="voce@dms.com.br"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={enviando}
                aria-invalid={Boolean(erros.email)}
                aria-describedby={erros.email ? 'org-email-erro' : undefined}
              />
              {erros.email && (
                <p id="org-email-erro" className="text-xs text-destructive">
                  {erros.email}
                </p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="org-senha">Senha</Label>
              <Input
                id="org-senha"
                type="password"
                autoComplete="current-password"
                placeholder="••••••••"
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
                disabled={enviando}
                aria-invalid={Boolean(erros.senha)}
                aria-describedby={erros.senha ? 'org-senha-erro' : undefined}
              />
              {erros.senha && (
                <p id="org-senha-erro" className="text-xs text-destructive">
                  {erros.senha}
                </p>
              )}
            </div>

            {erroGeral && (
              <p
                role="alert"
                className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
              >
                {erroGeral}
              </p>
            )}

            <Button
              type="submit"
              variant="primary"
              className="w-full"
              disabled={enviando}
            >
              {enviando && <Loader2 className="animate-spin" aria-hidden />}
              Entrar
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
