# apps/admin — Retaguarda (React + Vite)

SPA React + Vite + Tailwind + shadcn/ui. Backoffice: cardápio, relatórios, painel de frota, fila de reimpressão, conflitos de sincronização de catálogo.

- Monta e publica o cardápio da loja (categorias, produtos, combos, complementos, preços, disponibilidade, fotos).
- Painel de **frota/telemetria** (heartbeat, status de papel/pinpad, OTA).
- **De-para PDV**: gerencia `external_refs[] {sistema, codigo_pdv, loja}` por produto.

## Stack

React 18 · Vite 5 · TypeScript 5.4 · Tailwind 3.4 · shadcn/ui (montado à mão) · TanStack Query 5 · react-router-dom 6 · axios · zod. Testes: vitest 2 + @testing-library/react + jsdom + MSW.

## Como rodar

```bash
pnpm install                      # na raiz do monorepo (C:\GoGeM)
cp apps/admin/.env.example apps/admin/.env.local   # defina VITE_API_URL
pnpm -F @gogem/admin dev          # dev server (Vite, porta 5173)
pnpm -F @gogem/admin build        # tsc -b && vite build → dist/
pnpm -F @gogem/admin preview      # serve o build
pnpm -F @gogem/admin typecheck    # tsc --noEmit
pnpm -F @gogem/admin test         # vitest run
pnpm -F @gogem/admin lint         # eslint
```

### Variáveis de ambiente

Só variáveis com prefixo `VITE_` são expostas ao cliente.

| Variável       | Exemplo                          | Uso                          |
| -------------- | -------------------------------- | ---------------------------- |
| `VITE_API_URL` | `http://localhost:3000/api/v1`   | Base da API núcleo (apps/api) |

## Autenticação (scaffold)

O cliente HTTP (`src/lib/api.ts`) já injeta `Authorization: Bearer <token>` (lido de `src/lib/auth-token.ts` — memória + espelho em localStorage) e, ao receber **401**, limpa o token e redireciona para `/login`. O `AuthProvider`/`RequireAuth` (`src/auth/auth-context.tsx`) protegem as rotas privadas. As telas de login/registro são **stubs não-funcionais**; a lógica real de login entra no PR B.

## Tema (dark por padrão, sem light mode)

Tokens da marca GoGeM mapeados para variáveis CSS semânticas (estilo shadcn) em `src/index.css`; o Tailwind os consome via `hsl(var(--...))` em `tailwind.config.ts`.

| Papel                 | Cor       | Variável CSS   | Token semântico        |
| --------------------- | --------- | -------------- | ---------------------- |
| Fundo                 | `#0F1713` | `--background` | `bg-background`        |
| Painéis / cards       | `#16211B` | `--card`       | `bg-card`, `bg-popover`|
| Bordas / inputs       | `#2A3A31` | `--border`     | `border-border`, `input` |
| Ação primária (âmbar) | `#FFC24B` | `--primary`    | `bg-primary`, `ring`   |
| Sucesso / confirmação (menta) | `#3ECF8E` | `--success` / `--accent` | `bg-success`, `bg-accent` |
| Texto claro           | —         | `--foreground` | `text-foreground`      |

Tipografia: **Tektur** (display/`font-display`) e **Manrope** (corpo/`font-sans`), carregadas via Google Fonts em `index.html`.

> Assets definitivos de marca (logotipo/monograma) são follow-up de branding; por ora o wordmark é texto Tektur em `src/components/brand/gogem-mark.tsx`.

## Estrutura

```
src/
  App.tsx                 # providers (Query + Auth + Router) + rotas
  main.tsx                # bootstrap
  index.css               # Tailwind + tokens do tema GoGeM
  auth/auth-context.tsx   # AuthProvider stub + RequireAuth
  components/
    app-shell/            # shell.tsx (layout autenticado) + sidebar.tsx
    brand/gogem-mark.tsx  # wordmark
    page-placeholder.tsx  # estado vazio "em construção"
    ui/                   # button, card, input, label (shadcn-style)
  lib/
    api.ts                # cliente axios (JWT + 401)
    auth-token.ts         # storage do token
    query.ts              # QueryClient
    utils.ts              # cn()
  routes/                 # login, registro, catalogo, importar, publicar, frota
  test/msw/server.ts      # servidor MSW (sem handlers ainda)
test/
  setup.ts                # jest-dom + MSW lifecycle
  smoke.test.tsx          # teste de fumaça (renderiza /login)
```

> CRUD de catálogo entra no **S1–S2**; painel de frota no **S5**. Este PR entrega apenas o andaime (shell, tema, cliente de API, rotas e CI).
