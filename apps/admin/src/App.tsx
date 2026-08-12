import { QueryClientProvider } from '@tanstack/react-query';
import {
  BrowserRouter,
  Navigate,
  Outlet,
  Route,
  Routes,
} from 'react-router-dom';
import { queryClient } from '@/lib/query';
import { AuthProvider, RequireAuth } from '@/auth/auth-context';
import { OrgAuthProvider, RequireOrgAuth } from '@/auth/org-auth-context';
import { Shell } from '@/components/app-shell/shell';
import { ConsoleShell } from '@/components/distribuicao/console-shell';
import LoginPage from '@/routes/login';
import RegistroPage from '@/routes/registro';
import CatalogoPage from '@/routes/catalogo';
import CardapiosPage from '@/routes/cardapios';
import ConfiguracoesPage from '@/routes/configuracoes';
import IntegracoesPage from '@/routes/integracoes';
import OpenDeliveryPage from '@/routes/open-delivery';
import PublicarPage from '@/routes/publicar';
import RelatoriosPage from '@/routes/relatorios';
import FrotaPage from '@/routes/frota';
import OrgLoginPage from '@/routes/distribuicao/login';
import DistribuicaoHome from '@/routes/distribuicao/home';
import VersoesPage from '@/routes/distribuicao/versoes';
import EmBreve from '@/routes/distribuicao/em-breve';

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            {/* Públicas */}
            <Route path="/login" element={<LoginPage />} />
            <Route path="/registro" element={<RegistroPage />} />

            {/* Console da Distribuição (organização/DMS) — provider e sessão
                PRÓPRIOS, isolados do admin do cliente. */}
            <Route
              element={
                <OrgAuthProvider>
                  <Outlet />
                </OrgAuthProvider>
              }
            >
              <Route path="/distribuicao/login" element={<OrgLoginPage />} />
              <Route
                path="/distribuicao"
                element={
                  <RequireOrgAuth>
                    <ConsoleShell />
                  </RequireOrgAuth>
                }
              >
                <Route index element={<DistribuicaoHome />} />
                <Route path="versoes" element={<VersoesPage />} />
                <Route
                  path="telemetria"
                  element={<EmBreve titulo="Telemetria" />}
                />
              </Route>
            </Route>

            {/* Privadas (dentro do Shell) */}
            <Route
              element={
                <RequireAuth>
                  <Shell />
                </RequireAuth>
              }
            >
              <Route path="/catalogo" element={<CatalogoPage />} />
              <Route path="/cardapios" element={<CardapiosPage />} />
              <Route path="/integracoes" element={<IntegracoesPage />} />
              <Route path="/open-delivery" element={<OpenDeliveryPage />} />
              {/* Rota antiga: redireciona para a área de Integrações. */}
              <Route
                path="/importar"
                element={<Navigate to="/integracoes" replace />}
              />
              <Route path="/publicar" element={<PublicarPage />} />
              <Route path="/relatorios" element={<RelatoriosPage />} />
              <Route path="/configuracoes" element={<ConfiguracoesPage />} />
              <Route path="/frota" element={<FrotaPage />} />
            </Route>

            {/* Default + fallback */}
            <Route path="/" element={<Navigate to="/catalogo" replace />} />
            <Route path="*" element={<Navigate to="/catalogo" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
