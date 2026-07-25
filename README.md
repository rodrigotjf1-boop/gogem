# GoGeM by DMS

Plataforma white-label de **autoatendimento** para food service (totem em modo quiosque), com retaguarda multi-tenant, telemetria de frota, TEF/PIX, fiscal (NFC-e) e integração nativa com o **Regem**.

> *Regem governa · Farol guia · GoGeM atende.*

## Estrutura do monorepo

| Caminho | Conteúdo |
|---|---|
| `apps/kiosk` | App de totem — Flutter (Android armeabi-v7a/arm64 + Windows). |
| `apps/api` | API núcleo — NestJS + TypeScript + Prisma (PostgreSQL). REST + WS + OpenAPI. |
| `apps/admin` | Retaguarda — React + Vite + Tailwind + shadcn/ui. |
| `packages/contracts` | DTOs/tipos compartilhados; OpenAPI é a fonte da verdade. |
| `packages/escpos` | Driver de impressão (ESC/POS, ASB, near-end) em Dart. |
| `packages/payment` | Contrato `PaymentProvider` + adaptadores (SiTef, PayGo, PIX). |
| `integrations/regem` | Cliente da API do Regem + [`ENDPOINTS.md`](integrations/regem/ENDPOINTS.md) (contrato mapeado do código real). |
| `infra` | Templates EasyPanel/Docker, scripts de deploy. |
| `docs` | [Roadmap](docs/roadmap-execucao-gogem.md), runbooks, manual de provisionamento. |

## Começando

```bash
pnpm i                       # instala workspaces (Node 20 + pnpm)
pnpm lint && pnpm typecheck  # portões obrigatórios antes de commit
```

Consulte o [`CLAUDE.md`](CLAUDE.md) para as convenções inegociáveis e o [roadmap](docs/roadmap-execucao-gogem.md) para os sprints (S0–S12+).

## Estado atual

**S0 — Setup.** Este repositório está no estágio de **andaime**: estrutura de pastas, convenções, CI e o contrato de integração com o Regem. O código dos apps entra a partir do S1 (Fundação + Catálogo).
