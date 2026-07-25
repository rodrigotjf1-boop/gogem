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
 * Tela de registro — STUB não-funcional (scaffold do PR A).
 * A criação de conta/tenant real chega no PR B.
 */
export default function RegistroPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <GogemMark className="text-2xl" />
          <CardTitle className="pt-2">Criar conta</CardTitle>
          <CardDescription>Cadastre sua loja no GoGeM</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={(e) => e.preventDefault()}>
            <div className="space-y-2">
              <Label htmlFor="loja">Nome da loja</Label>
              <Input id="loja" type="text" placeholder="Minha Loja" disabled />
            </div>
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
                autoComplete="new-password"
                placeholder="••••••••"
                disabled
              />
            </div>
            <Button type="submit" variant="primary" className="w-full" disabled>
              Criar conta
            </Button>
            <p className="text-center text-xs text-muted-foreground">
              Registro será habilitado no próximo PR.{' '}
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
