import { Link } from 'react-router-dom';
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

/**
 * Tela de login — STUB não-funcional (scaffold do PR A).
 * A autenticação real (chamada à API + persistência) chega no PR B.
 */
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <GogemMark className="text-2xl" />
          <CardTitle className="pt-2">Entrar</CardTitle>
          <CardDescription>Retaguarda GoGeM by DMS</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            className="space-y-4"
            onSubmit={(e) => e.preventDefault()}
            aria-describedby="login-stub-aviso"
          >
            <div className="space-y-2">
              <Label htmlFor="email">E-mail</Label>
              <Input
                id="email"
                type="email"
                autoComplete="username"
                placeholder="voce@loja.com.br"
                disabled
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="senha">Senha</Label>
              <Input
                id="senha"
                type="password"
                autoComplete="current-password"
                placeholder="••••••••"
                disabled
              />
            </div>
            <Button type="submit" variant="primary" className="w-full" disabled>
              Entrar
            </Button>
            <p
              id="login-stub-aviso"
              className="text-center text-xs text-muted-foreground"
            >
              Login será habilitado no próximo PR.{' '}
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
