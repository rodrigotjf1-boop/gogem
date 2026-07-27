# Repasse ao Fable — Kiosk PR #17 (atualizado 2026-07-27)

> **Leia esta seção primeiro** (a partir da linha divisória vem o handoff amplo antigo).
> PR **#17** (`feat/kiosk-completo`) — app do totem F1–F6 + `packages/escpos`.
> Jobs `admin`, `escpos` e `lint` **verdes**; job **Kiosk (Flutter)** ainda vermelho.

### ✅ Já corrigi (commit 733095f, na sua branch — dê `git pull` antes de mexer)
**`apps/kiosk/lib/printing/fila_impressao.dart` — a fila de reimpressão não persistia.**
`enfileirar` gravava o cupom como `List<int>` cru numa coluna `BLOB`; o sqflite só binda
bytes como `Uint8List` → estourava `Invalid sql argument type 'List<int>'`. Efeito real no
totem: **toda** reimpressão falhava (justo o diferencial nº1 — não perder o pedido pago
quando falta papel). No CI isso derrubava `fila_impressao_test`, `admin_panel_test`,
`venda_sync`, `printer_gates` e gerava **timeouts de 10 min** (a exceção deixava async
pendente → job de ~40 min). Fix: `'cupom': Uint8List.fromList(cupom)`. A leitura
(`admin_panel_screen`) já esperava `Uint8List` (que é `List<int>`), então fica coerente.
Verificado local: `flutter analyze` limpo + `test/fila_impressao_test.dart` verde.

### ❌ Pendente — é seu (comportamento de UI)
**1) `test/descanso_navegacao_test.dart` — "5 toques no canto abrem o portão admin".**
Espera `find.text('ACESSO RESTRITO')` após 5 `tapAt(Offset(40,40))`; encontra **0**.
Em `lib/features/descanso/descanso_screen.dart` o `GestureDetector` de **tela cheia**
(`onTap: context.go('/catalogo')`, opaque) concorre com o **portão admin** de canto
(`Positioned(0,0,96,96)` → `_tapAdminCorner` → `context.push('/admin')` no 5º toque). Ou a
arena premia o detector externo (navega pro catálogo já no 1º toque; toques 2–5 caem no
catálogo), ou o `/admin` não renderiza `ACESSO RESTRITO`/os `k0..k9` dentro de 800x600.
Escolha conforme sua UX: fazer o canto **vencer** o toque (ex.: `onTapDown` no canto, ou
excluir a região do canto do `onTap` externo, ou tirar o portão da subárvore do GD externo);
se o `/admin` abre mas estoura layout, o keypad `GridView` k0..k9 precisa caber (envolver em
`SingleChildScrollView`/`shrinkWrap`). **Harness:** a tela tem `AnimationController.repeat()`
— nunca `pumpAndSettle`; `pump(Duration)` fixo (já anotado no topo do teste).

**2) Teste com `Expected: <2> / Actual: <3>`** (no log do CI, antes das stacks da fila) —
uma contagem quebrou (provável `catalogo_screen_test`/`checkout_flow_test`: espera 2, há 3).
Rode local e ajuste teste **ou** código conforme a intenção. O CI aponta o arquivo.

**3) Rode o job Kiosk do #17** depois do meu fix e confirme o placar — o esperado é sobrar só
(1) e (2). Se algum teste de impressão ainda cair, me chame (tenho o SDK e sirvo de gate).

### Gate de pré-voo (antes de empurrar)
`cd apps/kiosk && flutter analyze --fatal-infos && flutter test` — sem `withOpacity`/`withValues`
(use `withAlpha`/`Color` const); sem `pumpAndSettle` com `.repeat()`; tap dentro de 800x600;
1 commit pt-BR; **não** faça merge com o job do kiosk vermelho.

---

# Repasse técnico — GoGeM (handoff para o Fable)

> Documento de repasse do **GoGeM by DMS** (plataforma de autoatendimento/totem).
> Atualizado em 2026-07-25. Leia junto: `CLAUDE.md` (convenções inegociáveis),
> `docs/roadmap-execucao-gogem.md` (sprints), `docs/deploy-staging-gogem.md`
> (runbook de deploy) e `integrations/regem/ENDPOINTS.md` (contrato Regem).

---

## 0. TL;DR — onde estamos

- **Backend (API núcleo, S1–S2) COMPLETO e verde**: auth JWT/RBAC, multi-tenant real (isolamento *fail-closed*), CRUD de catálogo (categorias, produtos, complementos), publicação versionada e **import do catálogo do Regem por `codigo_pdv`**. Consolidado no **PR #10** (a caminho da `main`).
- **Admin web (retaguarda)**: andaime pronto (PR #7, já na `main`). Faltam as telas de auth/catálogo/import/publicar (PRs B–E).
- **Deploy**: pacote pronto (Dockerfile, migration inicial versionada, env de exemplo, smoke test, runbook). **Banco decidido: Postgres no EasyPanel** (`gogem-db`), não Supabase.
- **Regem**: os 2 endpoints da integração existem (venda de totem + leitura de catálogo por dispositivo) — PRs #226/#228.
- **O que falta para testar nos equipamentos** (ordem de valor): (1) **subir o backend** no EasyPanel; (2) **construir o app do totem em Flutter** (não existe nenhum código — é o PEDIDO deste doc, §6); (3) 2 pendências de backend que o totem depende: **pareamento de dispositivo** e **endpoint de venda no GoGeM que repassa ao Regem** (§7).
- Tudo que existe **compila e passa nos testes unitários (sem banco/hardware)**; **nada foi testado contra Postgres real nem em totem** ainda.

---

## 1. Estado dos repositórios e PRs

### GoGeM — `github.com/rodrigotjf1-boop/gogem` (privado, monorepo pnpm)
Na `main`: andaime (S0) + bootstrap da API (#1) + andaime do admin (#7).

**PR #10 (`fix/land-api-stack → main`, CI verde)** consolida TODO o backend + o pacote de deploy. Contexto: os PRs #2–#6/#8 foram empilhados e mergeados nos branches-base por engano (não na `main`), então o código não tinha chegado na `main`; o #10 corrige isso num único merge. **Mergear o #10 primeiro.** Depois dá para apagar os branches antigos (`feat/api-*`, `feat/deploy-staging`).

Após o #10, a `main` terá: API completa + admin (andaime) + Dockerfile + migration + runbook.

### Regem — `github.com/rodrigotjf1-boop/regem` (privado)
| PR | Título | Nota |
|---|---|---|
| #224 | ENDPOINTS.md (contrato) | só doc |
| #226 | L-VEN-1: `POST /api/v1/vendas/externa-pdv` | ⚠️ requer **migration 146** (`comanda.cpf`) na nuvem |
| #228 | L-CAT-2: `GET /api/v1/sync/catalogo` | leitura de catálogo por dispositivo |

---

## 2. Arquitetura da API (GoGeM `apps/api`)

NestJS 10 + TypeScript + **Prisma 5** (PostgreSQL). Prefixo `/api/v1`. Swagger em `/api/v1/docs`. `helmet` + **CORS** (var `CORS_ORIGIN`) + `ValidationPipe(whitelist, forbidNonWhitelisted)`. Testes: **vitest, 73 (sem banco)**.

- **Multi-tenant real (fail-closed):** `TenantContext` (AsyncLocalStorage) + middleware `$use` do Prisma injeta `tenantId` em toda query dos modelos escopados; query sem tenant lança `ForbiddenException`. **Nos services nunca se adiciona `tenantId` à mão** (padrão `satisfies Omit<...,'tenantId'>` + cast). `runAsSystem` = escotilha só para register/login.
- **Auth:** `POST /auth/register` (cria Tenant + presidente, bcryptjs), `/auth/login` (401 genérico), `GET /auth/me`. JWT `{ sub, tenant, papel, email }`, 12h. RBAC por hierarquia `presidente>gerente>supervisao>execucao`.
- **Catálogo:** `/categorias`, `/produtos` (+ `PUT /produtos/:id/external-refs`), `/produtos/:id/grupos`, `/grupos/:id/opcoes`. Escrita `gerente+`. **Preços em centavos inteiros.** De-para em `externalRefs = [{sistema, codigo_pdv, loja?}]`.
- **Import Regem:** `POST /import/regem` (gerente+) — puxa `GET {REGEM_API_BASE}/sync/catalogo` (X-Sync-Token), reais→centavos, idempotente por `codigo_pdv`.
- **Publicação:** `POST /catalogo/publicar`, `GET /catalogo/versoes`, `GET /catalogo/publicado?desde=<versao>` (snapshot imutável; delta por versão). ⚠️ **hoje JWT** — ver pendência §7.
- **Modelo (Prisma):** `Tenant, Unidade, Usuario (enum Papel), Categoria, Produto (precoCentavos, externalRefs Json, disponivel), ComplementoGrupo (min/max/obrigatorio), ComplementoOpcao (precoCentavosDelta, externalRefs), MenuVersion (versao, snapshot Json)`.

---

## 3. Deploy (staging) — o que está pronto e o que é manual

Runbook completo: `docs/deploy-staging-gogem.md`. **Banco: Postgres no EasyPanel (`gogem-db`)** — decisão tomada; nenhuma mudança de código.

Pronto no repo:
- `apps/api/Dockerfile` (multi-stage; CMD roda `prisma migrate deploy` antes do `node`) + `.dockerignore`.
- **Migration inicial versionada** em `apps/api/prisma/migrations/..._init` (8 tabelas), gerada contra o schema completo via `prisma migrate diff --from-empty`.
- `apps/api/env.staging.example`, `smoke-test.sh`.
- Correções de deploy já aplicadas: **prisma em `dependencies`** (sobrevive ao `prune --prod`) e **CORS** habilitado (senão o admin cross-origin quebra).

Manual (no EasyPanel, é do operador — não do agente): criar projeto `gogem-staging` → `gogem-db` (Postgres 16) → `gogem-api` (build pelo `apps/api/Dockerfile`, contexto = raiz) → env (DATABASE_URL interno, JWT_SECRET, CORS_ORIGIN, REGEM_*) → domínio `api.gogem.com.br` (TLS) → DNS A record → deploy → `smoke-test.sh`. **Redis e MinIO podem ser pulados por ora** (o código ainda não os usa). Domínio `www.gogem.com.br` já contratado; usar subdomínios `api.` e `app.`.

Lado Regem (destrava o import e a venda): deploy #226/#228 + **aplicar a mig 146** + cadastrar um `equipamento` tipo `servidor_local` no tenant do cliente → o `token` vira `REGEM_SYNC_TOKEN`.

---

## 4. Integração Regem (contrato que o GoGeM consome)

Detalhe em `integrations/regem/ENDPOINTS.md`. Chave do de-para: **`produto.codigo`** no Regem (`(tenant_id, codigo)`), guardado no GoGeM em `externalRefs`.

- **Ler catálogo** — `GET /api/v1/sync/catalogo` (Regem, `X-Sync-Token`): categorias + produtos (com `codigo`) + grupos/opções (com `codigoPdv`, `precoDelta`). ⚠️ `precoVenda`/`precoDelta` vêm como **string decimal em reais** (converter para centavos).
- **Vender de volta** — `POST /api/v1/vendas/externa-pdv` (Regem, `X-Sync-Token`): `{ idempotencyKey, itens:[{codigoPdv, quantidade, observacao?}], pagamentos:[{forma, valor, nsu?, autorizacao?}], cpf?, taxaServicoPct? }`. Baixa estoque imediata, pré-pago sem sessão de caixa, emite NFC-e se ativo, idempotente. **v1 sem complementos por item** e **CPF não vai no XML da NFC-e** ainda (follow-ups no Regem).

---

## 5. Como rodar localmente

```bash
# raiz C:\GoGeM  (pnpm; use `corepack pnpm@9` se pnpm não estiver no PATH)
pnpm install
# API
pnpm -F @gogem/api exec prisma generate
pnpm -F @gogem/api run build && pnpm -F @gogem/api run test   # 73 testes
pnpm -F @gogem/api run dev     # precisa de Postgres p/ /health/db
# Admin
pnpm -F @gogem/admin run dev    # Vite :5173 (defina VITE_API_URL)
```

---

## 6. ⭐ PEDIDO — App do Totem (Flutter) — `apps/kiosk`

> **Este é o maior bloco pendente e o que falta para instalar/testar nos equipamentos.** Hoje `apps/kiosk` está VAZIO (só README). Os 4 totens (Tinker Board S / Android 11, ARM 32-bit, 2GB) já estão disponíveis; falta o software.

**Objetivo:** app de autoatendimento em **modo quiosque** que baixa o cardápio publicado do GoGeM, monta o pedido, imprime (não-fiscal primeiro) e lança a venda de volta. Direção de arte "game menu" dark (roadmap §8).

**Stack:** Flutter (Android **armeabi-v7a** + arm64 + Windows). Estado com Riverpod ou Bloc. **SQLite** local (offline-first). Sem WebView no fluxo principal, sem libs de UI pesadas (2GB RAM).

**Contrato que consome (já pronto no backend):**
- **Cardápio publicado:** `GET /api/v1/catalogo/publicado?desde=<versao>` → snapshot `{ versao, snapshot: { categorias[], produtos[{ nome, precoCentavos, disponivel, externalRefs, grupos:[{min,max,obrigatorio, opcoes:[{nome, precoCentavosDelta, externalRefs}]}] }] } }`. `desde >= versao_atual` → `{ atualizado:false }` (checagem barata). **Preços em centavos.**
- **Venda de volta:** ver §7 (o totem deve chamar o GoGeM, que repassa ao Regem — endpoint a construir).

**Fatias sugeridas (PRs pequenos, cada um com teste + build verde):**
1. **Andaime Flutter** — projeto, navegação, tema dark, perfis de hardware (flag p/ desligar blur/partículas no RK3288), fontes/ícones. Build Android (armv7/arm64).
2. **Sync do cardápio** — cliente HTTP + baixar o snapshot publicado, persistir em SQLite (fonte da verdade local), sincronizar por `desde=<versao>` (delta), cache de imagens WebP. **Funciona offline** (usa o último snapshot).
3. **Fluxo de pedido** — descanso → categorias → produto → complementos (respeitando `min/max/obrigatorio` dos grupos) → carrinho → identificação (CPF opcional) → pagamento (**mock primeiro**). ≤6 toques para pedido simples; acessibilidade (alto contraste, modo rebaixado).
4. **Impressão ESC/POS** (`packages/escpos`, Dart) — **diferencial nº1 (gestão de papel):** ASB (`GS a`), consulta síncrona `DLE EOT` nos **portões** do fluxo, sensor near-end. Impressão de pedido **não-fiscal**. Regra: **totem bloqueia o pedido ANTES do pagamento se estiver sem papel** (nunca cobrar sem poder concluir). Alvo: Epson **TM-T88VII**.
5. **Kiosk mode** — Android: launcher próprio + watchdog (legado) / Device Owner (novo). Windows: Shell Launcher (depois).
6. **Lançar a venda** — ao concluir, POST no endpoint de venda do GoGeM (§7), com `idempotencyKey` (UUID gerado no totem — reenvio nunca duplica).
7. **(depois, com hardware)** TEF via `packages/payment` (CliSiTef — presencial, pinpad Gertec PPC930; **não** é a API REST do e-SiTef) e fiscal.

**Restrições inegociáveis (CLAUDE.md):**
- **Idempotência primeiro:** todo pedido nasce com UUID no totem; endpoints de escrita aceitam a chave; reenvio jamais duplica venda.
- **Offline-first:** SQLite é a verdade local; fila de sync com backoff; app funciona sem rede exceto TEF.
- **De-para SEMPRE por `codigo_pdv`**, nunca id interno.
- **Impressora:** nunca iniciar pagamento sem `DLE EOT` OK; ASB sempre ligado; papel/tampa mudam o estado do totem e geram evento de telemetria.
- **Nunca acoplar a integradora TEF:** tudo atrás do contrato `PaymentProvider` (`packages/payment`).
- **Segurança:** nada de segredos no repo; token por dispositivo (pareamento por código); logs sem dados de cartão.

**Critério de aceite (S3–S4 do roadmap):** *"pedido completo impresso no totem nº1 sem rede; ao remover o papel, o totem bloqueia ANTES do pagamento e alerta."*

---

## 7. Pendências de BACKEND que destravam o totem (não são do Fable — são do backend GoGeM)

Estas duas precisam existir no `apps/api` para o totem funcionar ponta a ponta. **Enquanto não existem, o Fable desenvolve o app contra um JWT de dev/staging.**

1. **Pareamento de dispositivo (totem ↔ GoGeM)** — hoje `GET /catalogo/publicado` é **JWT**; o totem não tem como se autenticar. Falta: emitir código de pareamento no admin → o totem troca por um **token de dispositivo**; e **trocar o guard** de `/catalogo/publicado` (e do endpoint de venda) para aceitar esse token. Tamanho: **M**.
2. **Endpoint de venda no GoGeM que repassa ao Regem** — arquitetura correta: **o totem fala só com o GoGeM**, e o GoGeM lança no Regem (guardando o `REGEM_SYNC_TOKEN`). Evita espalhar o token do Regem em cada totem. Falta: `POST /api/v1/vendas` (device-authed) no GoGeM que recebe a venda e chama `POST /vendas/externa-pdv` do Regem (idempotente, mapeando `codigo_pdv`/pagamentos/cpf). Tamanho: **M**.

> Recomendação de divisão: **eu (backend) construo as pendências §7**; o **Fable** toca o **app Flutter §6**, começando contra um JWT/token de staging e plugando no token de dispositivo quando §7.1 existir.

---

## 8. Outras pendências (construíveis, sem hardware)
| Item | Onde | Tamanho |
|---|---|---|
| Admin PRs **B–E** (auth, catálogo, import/publicar, frota) | `apps/admin` | G (fatiado) |
| CRUD de **Unidade/loja** | `apps/api` | P |
| **Backend de telemetria/frota** (ingestão de heartbeat + consultas) | `apps/api` | M |
| Extrair client Regem para o pacote `integrations/regem` | repo | P |
| Decisão: **login por e-mail** global vs único-por-tenant | `apps/api` | P (decisão) |

## 9. Fronteira de hardware/homologação (não dá para concluir só no código)
- **App do totem (Flutter)** — §6, precisa dos totens para validar performance/kiosk/impressão.
- **TEF** (`packages/payment`) — **CliSiTef** (presencial) + pinpad PPC930 + credenciamento na Software Express (NÃO é a API REST do e-SiTef, que é online/cartão-não-presente).
- **Fiscal NFC-e** — cert A1 por CNPJ + homologação SEFAZ (no Regem o transmissor SEFAZ é *stub* hoje).
- **Agente de telemetria** (roda no totem).

---

## 10. Riscos / atenção herdados
- Nada testado contra Postgres real nem hardware — o 1º `migrate deploy` num banco real pode expor ajustes.
- **Isolamento de tenant** depende do middleware + contexto (JWT): toda rota que toca modelo escopado precisa estar atrás de auth que popule o contexto.
- **Import é aditivo** e casa grupos/opções por **nome** — renomear no Regem duplica no GoGeM (evitar renomear no piloto).
- **Migrations Prisma**: a inicial está versionada; formalizar novas com `prisma migrate dev` antes de qualquer deploy com dados.
- No Regem: aplicar a **mig 146** junto do #226; venda de totem v1 sem complementos por item e sem CPF no XML da nota.
- **Merge de PRs empilhados**: mergear cada um no branch-base (não na `main`) espalha o código — daí o #10. Daqui pra frente, **cada frente branca da `main`** (sem stack).
