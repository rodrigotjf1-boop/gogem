import { Link } from 'react-router-dom';
import { PackageCheck, Activity } from 'lucide-react';
import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { useOrgAuth } from '@/auth/org-auth-context';

/** Visão geral do Console da Distribuição. Hub das áreas org-only. */
export default function DistribuicaoHome() {
  const { user } = useOrgAuth();
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <div>
        <h1 className="font-display text-2xl font-semibold">
          Console da Distribuição
        </h1>
        <p className="text-sm text-muted-foreground">
          Bem-vindo, {user?.nome ?? user?.email}. Área da organização (DMS) —
          cross-tenant, separada do admin dos clientes.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Link to="/distribuicao/versoes" className="block">
          <Card className="h-full transition-colors hover:border-primary">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <PackageCheck className="size-5 text-primary" aria-hidden />
                Versões
              </CardTitle>
              <CardDescription>
                Publicar e gerir as versões do totem (APK / Windows) que os
                aparelhos buscam no auto-update.
              </CardDescription>
            </CardHeader>
          </Card>
        </Link>

        <Link to="/distribuicao/telemetria" className="block">
          <Card className="h-full transition-colors hover:border-primary">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <Activity className="size-5 text-primary" aria-hidden />
                Telemetria
              </CardTitle>
              <CardDescription>
                Status e erros dos totens de todas as lojas, para acompanhar
                bugs e saúde da frota.
              </CardDescription>
            </CardHeader>
          </Card>
        </Link>
      </div>
    </div>
  );
}
