# CLAUDE.md — Monorepo GoGeM (autoatendimento · by DMS)

## O que é este projeto
Plataforma white-label de autoatendimento para food service: app de totem (Android ARM 32/64 + Windows) em modo quiosque, retaguarda multi-tenant com catálogo/relatórios/frota, API pública com webhooks, TEF (SiTef prioridade 1), PIX, fiscal (NFC-e/SAT) e integração nativa com o Regem. Roadmap completo em `docs/roadmap-execucao-gogem.md`.

## Estrutura
```
apps/kiosk    — Flutter (Android armeabi-v7a/arm64 + Windows). UI do totem, kiosk mode, ESC/POS, TEF.
apps/api      — NestJS + TypeScript + Prisma (PostgreSQL). REST + WebSocket + OpenAPI. Multi-tenant.
apps/admin    — React + Vite + Tailwind + shadcn/ui. Retaguarda (cardápio, relatórios, frota).
packages/contracts — DTOs/tipos compartilhados; OpenAPI é a fonte da verdade.
packages/escpos    — driver de impressão (ESC/POS, ASB, near-end) em Dart.
packages/payment   — contrato PaymentProvider + adaptadores (sitef/, paygo/, pix/).
integrations/regem — cliente da API do Regem + ENDPOINTS.md (contrato mapeado do código real).
infra/             — templates EasyPanel/Docker, CI GitHub Actions, scripts de deploy.
docs/              — roadmap, runbooks, manual de provisionamento do totem.
```

## Comandos
```bash
pnpm i                  # raiz (workspaces)
pnpm -F api dev         # API local (precisa de .env; docker compose up db redis minio)
pnpm -F admin dev
pnpm -F api test        # vitest
cd apps/kiosk && flutter run   # totem (dispositivo/emulador)
pnpm lint && pnpm typecheck    # obrigatórios antes de commit
```

## Convenções inegociáveis
1. **Idempotência primeiro**: todo pedido/pagamento nasce com UUID gerado no totem; endpoints de escrita aceitam `Idempotency-Key` e reenvio jamais duplica venda.
2. **Multi-tenant por `tenant_id`** em todas as tabelas de negócio + escopo automático no Prisma middleware. Nunca query sem tenant.
3. **Catálogo versionado**: alterações vão para rascunho; publicar gera `menu_versions`; o totem sincroniza por versão (delta).
4. **De-para PDV**: produtos carregam `external_refs[] {sistema, codigo_pdv, loja}`. Integração com Regem SEMPRE referencia `codigo_pdv`, nunca id interno.
5. **Impressora**: nunca iniciar pagamento sem `DLE EOT` OK; ASB ligado sempre; papel/tampa mudam estado do totem e geram evento de telemetria.
6. **TEF**: nenhuma confirmação sem cupom persistido; resolução de pendências no boot é obrigatória e testada (teste "tomada arrancada").
7. **Offline-first no totem**: SQLite é a verdade local; fila de sync com backoff; app funciona sem rede exceto TEF.
8. **Segurança**: nada de segredos no repo; tokens por dispositivo (pareamento por código); logs sem dados de cartão (PCI fica na integradora).
9. **API pública**: toda rota nova nasce documentada no OpenAPI de `packages/contracts`; breaking change = nova versão `/v2`.
10. PRs pequenos, com teste, descrição em PT-BR e checklist de aceite do sprint correspondente.

## Contexto de negócio que você deve lembrar
- Diferencial nº 1: gestão de papel (o concorrente Gototem trava pedido pós-pagamento quando o papel acaba — nós nunca).
- TEF confirmado do mercado-alvo: **SiTef/CliSiTef (Software Express-Fiserv)**; pinpad Gertec PPC 930 USB; impressora Epson TM-T88VII.
- Hardware legado alvo: Tinker Board S (Android 11, ARM 32-bit, 2GB) — performance importa; compilar armeabi-v7a.
- Kiosk mode: launcher próprio + watchdog (legado rooteado) / Device Owner (hardware novo); Windows: Shell Launcher.
- Infra: VPS Ubuntu com EasyPanel (staging/prod separados) + n8n para alertas WhatsApp.
- Nomes da família DMS: Regem (gestão) · Farol · GoGeM (este produto).

## Integração com o Regem
O contrato de integração (auth de serviço, catálogo por `codigo_pdv`, lançamento de venda, estoque, fechamento, fiscal, idempotência e eventos) está mapeado do código real do Regem em `integrations/regem/ENDPOINTS.md`. Pontos-chave já levantados:
- **Código PDV = `produto.codigo`** no Regem (chave `(tenant_id, codigo)`). É o alvo do de-para `external_refs`.
- **Auth de serviço**: o Regem não tem `client_credentials`; o encaixe é o token de dispositivo (`X-Sync-Token`). Evoluir para client-credentials na API pública (S12).
- **Lançamento de venda paga por `codigo_pdv`** é a lacuna #1 do piloto (L-VEN-1) — endpoint novo no Regem, adaptador fino sobre o fluxo externo existente.

## O que NÃO fazer
- Não usar bibliotecas de UI pesadas no kiosk (2GB RAM); nada de WebView para o fluxo principal.
- Não acoplar o app a uma integradora TEF: tudo via `packages/payment` (contrato `PaymentProvider`).
- Não criar migrações destrutivas sem plano de rollback.
- Não commitar assets binários grandes fora de `docs/` (usar MinIO/CDN).
