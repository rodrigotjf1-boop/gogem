# apps/api — API núcleo (NestJS + Prisma)

NestJS + TypeScript + **Prisma** (PostgreSQL). REST + WebSocket + OpenAPI. Multi-tenant.

- **Multi-tenant por `tenant_id`** com escopo automático no Prisma middleware — nunca query sem tenant (CLAUDE.md §2).
- **Idempotência primeiro**: escritas aceitam `Idempotency-Key`; reenvio jamais duplica venda (§1).
- **Catálogo versionado**: rascunho → publicar gera `menu_versions`; totem sincroniza por delta (§3).
- **OpenAPI** gerado alimenta `packages/contracts` (fonte da verdade do contrato) e a API pública (§9).

> Vazio no S0. Bootstrap (auth JWT/RBAC, tenants, lojas, catálogo) entra no **S1–S2** (Fundação + Catálogo).
