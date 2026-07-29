import { QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { queryClient } from '@/lib/query';
import { AuthProvider, RequireAuth } from '@/auth/auth-context';
import { Shell } from '@/components/app-shell/shell';
import LoginPage from '@/routes/login';
import RegistroPage from '@/routes/registro';
import CatalogoPage from '@/routes/catalogo';
import CardapiosPage from '@/routes/cardapios';
import ConfiguracoesPage from '@/routes/configuracoes';
import IntegracoesPage from '@/routes/integracoes';
import PublicarPage from '@/routes/publicar';
import FrotaPage from '@/routes/frota';

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            {/* Públicas */}
            <Route path="/login" element={<LoginPage />} />
            <Route path="/registro" element={<RegistroPage />} />

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
              {/* Rota antiga: redireciona para a área de Integrações. */}
              <Route
                path="/importar"
                element={<Navigate to="/integracoes" replace />}
              />
              <Route path="/publicar" element={<PublicarPage />} />
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
