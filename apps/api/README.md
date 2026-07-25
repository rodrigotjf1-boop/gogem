# apps/api — API núcleo (NestJS + Prisma)

NestJS 10 + TypeScript + **Prisma** (PostgreSQL). REST + WebSocket + OpenAPI. Multi-tenant.

- **Multi-tenant por `tenant_id`** com escopo automático no Prisma middleware — nunca query sem tenant (CLAUDE.md §2).
- **Idempotência primeiro**: escritas aceitam `Idempotency-Key`; reenvio jamais duplica venda (§1).
- **Catálogo versionado**: rascunho → publicar gera `menu_versions`; totem sincroniza por delta (§3).
- **De-para PDV**: `Produto.externalRefs` = `[{ sistema, codigo_pdv, loja }]` (§4).
- **OpenAPI** gerado alimenta `packages/contracts` (fonte da verdade do contrato) e a API pública (§9).

## Estado (S1 — Fundação)

Esqueleto **compilável e executável** (NÃO é o CRUD completo). Entregue:

- Bootstrap Nest com `setGlobalPrefix('api/v1')`, **helmet**, `ValidationPipe({ whitelist, transform, forbidNonWhitelisted })` e **Swagger** em `/api/v1/docs`.
- `PrismaService` (connect/disconnect no ciclo de vida) + **middleware `$use` de escopo por tenant (STUB documentado)**.
- Healthchecks: `GET /api/v1/health` (liveness) e `GET /api/v1/health/db` (`SELECT 1`).
- `IdempotencyInterceptor` — **STUB documentado** (§1).
- Schema Prisma: `Tenant`, `Unidade`, `Usuario` (enum `Papel` RBAC), `Categoria`, `Produto` (`externalRefs Json`), `MenuVersion`.
- Smoke test (vitest, sem DB) do health controller.

Stubs (a implementar no S1–S2): injeção real do `tenantId` no middleware (via AsyncLocalStorage a partir do auth), idempotência sobre Redis, auth JWT/RBAC, CRUD de catálogo, publicação versionada e import Regem.

## Rodar

```bash
# na raiz do monorepo
pnpm install
cp apps/api/.env.example apps/api/.env   # ajuste DATABASE_URL

pnpm -F @gogem/api exec prisma generate   # gera o Prisma Client
pnpm -F @gogem/api run build              # nest build
pnpm -F @gogem/api run typecheck          # tsc --noEmit
pnpm -F @gogem/api run test               # vitest (smoke, sem DB)

pnpm -F @gogem/api run dev                # nest start --watch (precisa de DB p/ /health/db)
```

- Swagger: `http://localhost:3000/api/v1/docs`
- Health: `http://localhost:3000/api/v1/health`

Migrations Prisma (`prisma migrate dev`) exigem um Postgres acessível via `DATABASE_URL` — fora do escopo do S1.
