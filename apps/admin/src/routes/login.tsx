import * as React from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
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
import { GogemMark } from '@/components/brand/gogem-mark';
import { useAuth } from '@/auth/auth-context';

const schema = z.object({
  email: z.string().email('Informe um e-mail válido'),
  senha: z.string().min(6, 'A senha deve ter ao menos 6 caracteres'),
});

type Campo = 'email' | 'senha';

/** Tela de login funcional: valida com zod e autentica na API real. */
export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const destino =
    (location.state as { from?: { pathname?: string } } | null)?.from
      ?.pathname ?? '/catalogo';

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
      const fieldErrors = parsed.error.flatten().fieldErrors;
      setErros({
        email: fieldErrors.email?.[0],
        senha: fieldErrors.senha?.[0],
      });
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
          <GogemMark className="text-2xl" />
          <CardTitle className="pt-2">Entrar</CardTitle>
          <CardDescription>Retaguarda GoGeM by DMS</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={onSubmit} noValidate>
            <div className="space-y-2">
              <Label htmlFor="email">E-mail</Label>
              <Input
                id="email"
                type="email"
                autoComplete="username"
                placeholder="voce@loja.com.br"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={enviando}
                aria-invalid={Boolean(erros.email)}
                aria-describedby={erros.email ? 'email-erro' : undefined}
              />
              {erros.email && (
                <p id="email-erro" className="text-xs text-destructive">
                  {erros.email}
                </p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="senha">Senha</Label>
              <Input
                id="senha"
                type="password"
                autoComplete="current-password"
                placeholder="••••••••"
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
                disabled={enviando}
                aria-invalid={Boolean(erros.senha)}
                aria-describedby={erros.senha ? 'senha-erro' : undefined}
              />
              {erros.senha && (
                <p id="senha-erro" className="text-xs text-destructive">
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
            <p className="text-center text-xs text-muted-foreground">
              Ainda não tem conta?{' '}
              <Link to="/registro" className="text-primary hover:underline">
                Criar conta
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
