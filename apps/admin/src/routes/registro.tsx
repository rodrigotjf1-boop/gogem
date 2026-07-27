import * as React from 'react';
import { Link, useNavigate } from 'react-router-dom';
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
  empresa: z.string().min(2, 'Informe o nome da loja'),
  nome: z.string().min(2, 'Informe seu nome'),
  email: z.string().email('Informe um e-mail válido'),
  senha: z.string().min(6, 'A senha deve ter ao menos 6 caracteres'),
});

type Campo = 'empresa' | 'nome' | 'email' | 'senha';

/** Tela de registro funcional: valida com zod e cria a conta na API real. */
export default function RegistroPage() {
  const { register } = useAuth();
  const navigate = useNavigate();

  const [empresa, setEmpresa] = React.useState('');
  const [nome, setNome] = React.useState('');
  const [email, setEmail] = React.useState('');
  const [senha, setSenha] = React.useState('');
  const [erros, setErros] = React.useState<Partial<Record<Campo, string>>>({});
  const [erroGeral, setErroGeral] = React.useState<string | null>(null);
  const [enviando, setEnviando] = React.useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErroGeral(null);
    const parsed = schema.safeParse({ empresa, nome, email, senha });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setErros({
        empresa: f.empresa?.[0],
        nome: f.nome?.[0],
        email: f.email?.[0],
        senha: f.senha?.[0],
      });
      return;
    }
    setErros({});
    setEnviando(true);
    try {
      await register(parsed.data);
      navigate('/catalogo', { replace: true });
    } catch {
      setErroGeral(
        'Não foi possível criar a conta. Verifique os dados e tente novamente.',
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
          <CardTitle className="pt-2">Criar conta</CardTitle>
          <CardDescription>Cadastre sua loja no GoGeM</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={onSubmit} noValidate>
            <div className="space-y-2">
              <Label htmlFor="empresa">Nome da loja</Label>
              <Input
                id="empresa"
                type="text"
                placeholder="Minha Loja"
                value={empresa}
                onChange={(e) => setEmpresa(e.target.value)}
                disabled={enviando}
                aria-invalid={Boolean(erros.empresa)}
                aria-describedby={erros.empresa ? 'empresa-erro' : undefined}
              />
              {erros.empresa && (
                <p id="empresa-erro" className="text-xs text-destructive">
                  {erros.empresa}
                </p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="nome">Seu nome</Label>
              <Input
                id="nome"
                type="text"
                autoComplete="name"
                placeholder="Ana Silva"
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                disabled={enviando}
                aria-invalid={Boolean(erros.nome)}
                aria-describedby={erros.nome ? 'nome-erro' : undefined}
              />
              {erros.nome && (
                <p id="nome-erro" className="text-xs text-destructive">
                  {erros.nome}
                </p>
              )}
            </div>
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
                autoComplete="new-password"
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
              Criar conta
            </Button>
            <p className="text-center text-xs text-muted-foreground">
              Já tem conta?{' '}
              <Link to="/login" className="text-primary hover:underline">
                Entrar
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
