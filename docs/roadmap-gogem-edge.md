# Roadmap — Totem GoGeM roteado pelo servidor EDGE (integração Regem)

> **Escopo travado.** GoGeM = **vendas locais de totem de autoatendimento**. Quando a loja tem **integração Regem**, o pedido do totem vai pro **servidor local (edge Regem)** que soma no **caixa** (financeiro) e baixa estoque/KDS na hora. O totem fala com **um concentrador** GoGeM instalado **na mesma caixa do edge**, que intermedia (local → edge Regem; nuvem → GoGeM cloud). Sem Regem (ou outro sistema) → modo **tradicional** (totem → nuvem GoGeM), intacto. Este documento é **plano**, nada implementado.

## 0. Decisões travadas (com o usuário)

1. **UM APK** com host **configurável em runtime**, entregue no **pareamento**.
2. **Opção B (concentrador)**: o totem fala **só com o concentrador** (device-token). O **loja-token do Regem fica no servidor**, nunca no aparelho. — *decisão de segurança, ver §2.1.*
3. **Pagamento cartão/PIX**: orquestrado pela **nuvem GoGeM** (MP), como hoje.
4. **Espelho do pedido na nuvem GoGeM = SIM**: a venda sobe pra base Prisma **por loja** e alimenta **relatórios/análises/financeiro** (RBAC presidente/C&O/gerente). Fonte da verdade do **caixa/estoque** = Regem edge; a nuvem é **espelho** pra gestão.
5. **Outras integrações**: nada muda (ver §6). Open Delivery = **protocolo** de interoperabilidade, fora do caminho do totem.

---

## 1. Decisão do APK — UM APK, host em runtime no pareamento

A fiação reativa **já existe**: o cliente HTTP recebe a base URL por construtor (`apps/kiosk/lib/data/api/gogem_api.dart:46`) via `gogemApiProvider` (`apps/kiosk/lib/data/catalog/catalog_sync.dart:43-49`), que reconstrói quando o pareamento muda. Falta:
1. `appConfigProvider` (hoje `const`, `apps/kiosk/lib/core/config/app_config.dart:22`) virar **mutável** / ler um override.
2. **Estender a resposta do pareamento** — hoje só devolve `token` (`gogem_api.dart:63-77`) — pra também trazer `apiBase` (host do concentrador **ou** nuvem) e config (provider de pagamento, impressora, kiosk lock).
3. **Persistir** o host na tabela SQLite `kv` (já existe, sem migração — `apps/kiosk/lib/data/db/kiosk_database.dart:57-60`), lido no boot como o `device_token` (`apps/kiosk/lib/core/pareamento/device_token.dart:35-45`).
4. **Greenfield**: `IOClient`/`HttpClient` confiando no **CA self-signed do edge** (`edge/certs/ca.pem`) — hoje usa `http.Client()` puro e rejeitaria (`gogem_api.dart:2,45`).

**Descoberta do host = config no pareamento** (o servidor já sabe se a loja tem edge e o IP LAN). mDNS fica como auto-heal **futuro/opcional**, nunca base. Um APK cobre loja com edge e sem edge (o host decide).

---

## 2. Arquitetura — Concentrador GoGeM (Opção B)

Serviço GoGeM enxuto rodando **na mesma caixa do edge Regem**. O totem tem **um endpoint só** (o concentrador); ele é quem fan-out.

### 2.1. Por que Opção B (segurança)
- Falar com o edge Regem exige o **loja-token** (`X-Sync-Token`/`X-Loja-Token`), credencial de **loja inteira** (posta venda, mexe estoque, pausa item) — nasce na nuvem Regem e sincroniza pro edge (`integracao_token`, `LojaTokenGuard`). O Regem **não tem token por dispositivo**.
- Se o totem falasse **direto** com o Regem, o loja-token estaria em **cada aparelho público** → um totem comprometido vaza a credencial da **loja toda**, e cortar exige rotacionar + reprovisionar todos.
- No concentrador, o totem carrega só o **device-token** (`X-Device-Token`) — **por dispositivo, escopado, revogável individual** (`apps/api/src/dispositivo/dispositivo.service.ts:176-210`; `revogar`→`ativo:false`). O **loja-token fica só no servidor** (como já é na nuvem, `RegemConfigResolver`). Mantém o invariante "totem só fala com o GoGeM" (`prisma/schema.prisma:632-640`).

### 2.2. Roteamento (o concentrador decide)
| O totem pede… | Concentrador → | Local/Nuvem |
|---|---|---|
| Cardápio (`/catalogo/publicado`) | edge Regem `GET /sync/catalogo` → serve no formato GoGeM | **local** |
| Registrar venda (`/vendas`) | edge Regem `POST /vendas/externa-pdv` (loja-token) → estoque/KDS/**caixa** na hora | **local** |
| Pausar item | edge Regem `POST /sync/produtos/pausa` | **local** |
| Pagamento cartão/PIX | **nuvem GoGeM** (cria intent MP, polling, resultado) | **nuvem** |
| Pareamento/config/telemetria | nuvem GoGeM | **nuvem** |
| (após a venda) espelho do pedido | **nuvem GoGeM** (Prisma, por loja) — relatórios/financeiro | **nuvem** (fila) |

### 2.3. Componentes
- **Ingress do totem (LAN)** — recebe `X-Device-Token`, mesmo contrato da nuvem (o APK não muda além do host). Porta local (ex.: `:3010`), HTTPS com o CA do edge.
- **Tradutor local** — converte chamadas GoGeM ↔ contrato Regem edge (`localhost:3002`, loja-token guardado **no servidor**). Reusa a lógica dos clients (`RegemSalesClient`/`RegemCatalogClient`/`RegemPauseClient`).
- **Espelho de cardápio** — materializa `GET /sync/catalogo` do Regem edge no formato `/catalogo/publicado` (snapshots `MenuVersion`) que o totem já consome.
- **Fila de upload pra nuvem** — sobe o `Pedido` pra base Prisma da nuvem (por loja) — **best-effort, com retry, sem perder venda**.
- **Proxy de nuvem** — repassa pagamento/telemetria/config pra `api.gogem.com.br` (egresso pelo roteador).
- **Single-tenant por caixa** — fixa um `tenantId` no `TenantContext` (o middleware fail-closed já exige tenant, `apps/api/src/prisma/tenant-scope.middleware.ts:65-71`).

### 2.4. Fluxo de uma venda (o coração)

**Cartão / PIX (precisa de internet):**
1. Totem → concentrador (device-token): "pagar R$X do pedido Y".
2. Concentrador → **nuvem GoGeM**: cria intent MP na maquininha daquele totem (`Dispositivo.pointDeviceId`; token MP da loja fica na nuvem — `psp-resolver.ts:33-46`).
3. Nuvem faz polling/webhook do MP; a **maquininha (internet própria)** cobra; MP confirma.
4. Nuvem → concentrador: **aprovado** (nsu/autorização) ou **rejeitado**.
5. Se aprovado: concentrador → **edge Regem** `POST /vendas/externa-pdv` (loja-token) com `itens[]` (codigoPdv), `pagamentos[]` (forma, valor, **nsu/autorizacao**), `idempotencyKey` → **estoque/KDS/caixa local na hora**.
6. Concentrador → totem: **liberado** (senha/comanda) ou **rejeitado**.
7. Concentrador → **fila**: sobe o `Pedido` pra nuvem GoGeM (relatórios/financeiro).

**Dinheiro (tolera internet caída):**
1-2. Totem → concentrador, forma=dinheiro.
3. Concentrador → **edge Regem** `/vendas/externa-pdv` direto (local, **sem internet**) → caixa.
4. Concentrador → totem: liberado. 5. Sobe espelho pra nuvem quando houver internet.

> **Regra de ouro:** cartão/PIX = **paga primeiro (nuvem), posta a venda depois** (com o resultado do pagamento). Nunca somar ao caixa antes de confirmar o pagamento eletrônico. O contrato `/vendas/externa-pdv` já aceita `pagamentos[]` com nsu/autorização.

### 2.5. O que sincroniza (nuvem GoGeM ↔ concentrador)
| Direção | O quê |
|---|---|
| **Nuvem → caixa (desce)** | `Integracao`(regem/mercadopago), `Dispositivo`/pareamento, config/aparência |
| **Caixa → nuvem (sobe)** | `Pedido` (espelho p/ relatórios/financeiro), pagamentos, telemetria/heartbeat |
| **Edge Regem → concentrador (local)** | catálogo (`/sync/catalogo`) |
| **Concentrador → edge Regem (local)** | vendas (`/vendas/externa-pdv`), pausa |

---

## 3. Ponto de atenção no fluxo GoGeM (a única mudança do lado GoGeM)

Hoje `VendasService.registrarVendaTotem` **acopla** "cria `Pedido` na nuvem **e** relaya pro Regem" (`apps/api/src/vendas/vendas.service.ts:139`, re-throw se o Regem falha `:158-168`). No modo edge isso **inverte**: quem posta no Regem é o **concentrador (local)**, e a nuvem passa a **receber o espelho** do pedido. Então o lado GoGeM precisa **desacoplar**: pagamento (nuvem) separado do registro-de-venda; e a nuvem ganha um caminho de **ingest do espelho** (grava `Pedido` sem re-relayar pro Regem). Nenhuma mudança no **Regem**; a mudança é **interna do GoGeM** e só ativa no modo edge (o modo tradicional segue usando o acoplado atual).

---

## 4. Fases (esforço relativo; correção > velocidade)

- **Fase 0 — PoC sem código** (baixo). Apontar `Integracao(regem).config.apiBase` no **nível empresa** (`unidadeId:null` — o sales client ignora `unidadeId`, `regem-sales.client.ts:86`) pra um Regem-edge alcançável e validar `POST /vendas/externa-pdv` (idempotência + estoque/KDS/caixa) e `GET /sync/catalogo`, com o **loja-token já sincronizado**. Valida contrato + janela do token. **Zero código.**
- **Fase 1 — Host em runtime no totem** (baixo-médio, só kiosk). Pareamento devolve `apiBase`; persistir em `kv`; provider mutável; `IOClient` com CA do edge. **UM APK.**
- **Fase 2 — Concentrador MVP** (alto). Ingress do totem + tradutor local (venda/catálogo/pausa → edge Regem) + espelho de cardápio. Single-tenant.
- **Fase 3 — Pagamento + espelho** (médio-alto). Concentrador orquestra pagamento **via nuvem**, posta a venda no Regem com o resultado, e **sobe o `Pedido` pra nuvem** (fila com retry). Desacoplar `registrarVendaTotem` no GoGeM (ingest de espelho).
- **Fase 4 — Resiliência/offline** (médio). Fila durável (dinheiro opera sem internet; cartão/PIX aguardam net); reprocesso idempotente (`(tenantId, idempotencyKey)`).
- **Fase 5 — Empacotar no instalador do edge + hardening** (médio). Serviço no instalador do edge Regem; host-por-tenant multi-loja; reserva DHCP; TLS; observabilidade (telemetria pro Console de Distribuição).

---

## 5. Pagamento no modelo edge

- **MP Point/PIX exigem egresso** pra `api.mercadopago.com` (`apps/api/src/pagamentos/psp/mercadopago-point.gateway.ts:1`, `mercadopago-psp.gateway.ts:8`). Orquestração fica na **nuvem GoGeM** (decisão #3) — reusa o que já existe e testado (webhook + reconcile).
- **Maquininha tem internet própria**; a MP roteia a intent por `pointDeviceId`. O totem/servidor só cria a intent e aguarda o resultado.
- **Offline**: sem internet → só **dinheiro** (local, direto no caixa) e **TEF on-device** (nsu/autorização viram metadados na venda, `apps/api/src/vendas/dto/venda-totem.dto.ts:43-72`). Cartão/PIX **precisam** de egresso.

---

## 6. Outras integrações — nada muda (§ requisitos)

O totem é **agnóstico à integração** (cliente fino, só contrato GoGeM; toda integração é server-side). O concentrador imita esse contrato → **transparente pro device** (segue **um APK**). O modo edge é **Regem-only e opt-in por loja** (host no pareamento + `Integracao(regem)` ativa).

- **Open Delivery** = **protocolo** (API provedora `/open-delivery/v1`, OAuth2), não um canal do totem → fora do caminho, **sem mudança**.
- **Mercado Pago** → nuvem pra todos → **sem mudança**.
- **Loja sem Regem / outro sistema** → pareamento entrega host = **nuvem GoGeM** → fluxo tradicional **intacto**.

**Como a loja escolhe o modo:**
| Tipo de loja | Host do totem | Venda/estoque/caixa | Cardápio | Pagamento | Relatórios/financeiro |
|---|---|---|---|---|---|
| **Regem + edge** | concentrador (LAN) | edge Regem (local) | Regem (espelhado) | nuvem GoGeM | nuvem GoGeM (espelho) |
| **Outro / nenhum** | nuvem GoGeM | nuvem GoGeM | admin GoGeM | nuvem GoGeM | nuvem GoGeM |

**Requisitos pra ligar o modo edge (Regem):** edge Regem na caixa + **concentrador na mesma caixa**; **loja-token sincronizado** antes do 1º uso; `Integracao(regem)` ativa; pareamento com host do concentrador; totem confiando no **CA do edge**.
**Requisitos do modo tradicional:** nenhum novo (default).

---

## 7. Riscos & decisões

| Tema | Decisão |
|---|---|
| Credencial no device | **Só device-token** no totem; **loja-token só no servidor** (Opção B). |
| Descoberta de IP do edge | Config no pareamento + **reserva DHCP**. mDNS = auto-heal futuro. |
| TLS local | HTTPS com **CA pinado** (`edge/certs/ca.pem`). |
| Janela do loja-token | Garantir **sincronizado antes do 1º uso**; concentrador falha-fechado e retém na fila. |
| Ordem pagamento×venda | Cartão/PIX: **paga → posta venda**. Nunca ao contrário. |
| Espelho na nuvem | **Fila durável com retry** (não perder venda); idempotência `(tenantId, idempotencyKey)`. |
| Desacoplar `registrarVendaTotem` | Mudança **interna GoGeM**, só no modo edge; tradicional intacto. |
| Multi-loja | Host por `Dispositivo`/`unidadeId` no pareamento; cada caixa → seu Regem edge. |
| Empacotamento | Concentrador no **instalador do edge Regem**. |

---

## 8. Resumo executivo

1. **UM APK**, host em runtime no pareamento; loja sem edge → nuvem (tradicional intacto).
2. **Opção B**: totem só fala com o **concentrador** (device-token); **loja-token só no servidor**. Local → edge Regem (`/vendas/externa-pdv`, caixa); nuvem → GoGeM cloud.
3. **Pagamento** na nuvem (MP); **paga → posta venda** no caixa local com o resultado.
4. **Espelho do pedido sobe pra nuvem** (Prisma, por loja) → relatórios/análises/financeiro (presidente/C&O/gerente). Fila com retry.
5. Única mudança do lado GoGeM: **desacoplar** venda×pagamento×relay (só no modo edge). **Nada muda no Regem nem nas outras integrações.**
6. Começar pela **Fase 0** (zero código).

---

## 9. Checklist de implementação (acompanhamento)

> Marque `[x]` ao concluir. Dono: **V** = você (Regem/edge/infra) · **C** = Claude (código GoGeM).

### Fase 0 — PoC sem código (validar contrato) — *pré-requisito de tudo*
- [ ] **V** Regem-edge alcançável com a API em `:3002` (IP LAN ou túnel)
- [ ] **V** loja-token **sincronizado** da nuvem Regem → edge (`integracao_token`)
- [ ] **V** `Integracao(regem).config.apiBase` no **nível empresa** (`unidadeId:null`), `ativo:true`, com o loja-token
- [ ] **C** validar `GET /sync/catalogo` (categorias/produtos vêm)
- [ ] **C** validar `POST /vendas/externa-pdv` (idempotência + estoque/KDS/**caixa**; replay = mesma comanda)
- [ ] **C** validar `POST /sync/produtos/pausa`
- ✅ *Sucesso:* venda de teste aparece no **caixa** do Regem edge, estoque baixou, catálogo veio.

### Fase 1 — Host em runtime no totem (kiosk)
- [ ] **C** `appConfigProvider` mutável / override lido por `gogemApiProvider`
- [ ] **C** pareamento (servidor) devolve `apiBase` + config além do `token`
- [ ] **C** persistir `apiBase` em `kv` + ler no boot
- [ ] **C** `IOClient`/`HttpClient` confiando no CA do edge (`edge/certs/ca.pem`)
- [ ] **C** fallback: sem `apiBase` → host **nuvem** (tradicional)
- [ ] **C/V** APK de teste validando a troca de host
- ✅ *Sucesso:* totem pareado aponta pro host entregue; loja sem edge → nuvem. **UM APK.**

### Fase 2 — Concentrador MVP
- [ ] **C** serviço na caixa (porta LAN, HTTPS com CA), **single-tenant** (tenantId fixo)
- [ ] **C** ingress do totem (`DeviceTokenGuard`, `X-Device-Token`)
- [ ] **C** tradutor venda: `/vendas` GoGeM → `/vendas/externa-pdv` Regem (**loja-token no servidor**)
- [ ] **C** tradutor cardápio: `/sync/catalogo` → `/catalogo/publicado` (`MenuVersion` local)
- [ ] **C** tradutor pausa
- ✅ *Sucesso:* totem vende **via concentrador** → cai no **caixa** Regem local. Loja-token nunca no device.

### Fase 3 — Pagamento + espelho na nuvem
- [ ] **C** concentrador orquestra pagamento **via nuvem GoGeM** (proxy MP)
- [ ] **C** ordenação **paga → posta venda** no Regem com nsu/autorização
- [ ] **C** fila de upload do `Pedido` pra nuvem (Prisma, **por loja**) com retry
- [ ] **C** desacoplar `VendasService.registrarVendaTotem` (ingest de espelho, sem re-relay Regem) — **só no modo edge**
- ✅ *Sucesso:* card/PIX aprova → venda no caixa **+ pedido espelhado na nuvem** (relatórios/financeiro).

### Fase 4 — Resiliência / offline
- [ ] **C** fila durável (dinheiro opera **sem internet**; cartão/PIX aguardam net)
- [ ] **C** reprocesso idempotente `(tenantId, idempotencyKey)`
- [ ] **C** falha-fechado se loja-token não sincronizou
- ✅ *Sucesso:* internet cai → dinheiro segue vendendo; volta → espelhos sobem sem duplicar.

### Fase 5 — Empacotar + hardening
- [ ] **V/C** concentrador no **instalador do edge Regem**
- [ ] **C** host-por-tenant (multi-loja)
- [ ] **V** reserva **DHCP** do edge no roteador
- [ ] **C/V** TLS/CA revisado + telemetria pro Console de Distribuição
- ✅ *Sucesso:* instalação nova sobe **edge + concentrador** juntos; multi-loja funciona.

---

## 10. Plano de execução detalhado (Fases 1–5)

> Legenda: **V** = você (Regem/edge/infra) · **C** = Claude (código GoGeM). Cada fase: *Objetivo · Entregáveis · Ordem · Aceite · Dependências/Decisões*.

### Fase 1 — Host em runtime no totem  *(100% GoGeM, testável já)*
- **Objetivo:** o totem recebe o host no pareamento (default = nuvem); base pra edge e tradicional.
- **Entregáveis:**
  - **C** *Server GoGeM* — `DispositivoService.parear` (`apps/api/src/dispositivo/dispositivo.service.ts:176-210`) passa a devolver `apiBase` (+ config) além de `{token,nome}`. Fonte do host: novo campo (ex.: `Dispositivo.edgeHost` ou por `Unidade`/`Integracao`). **Decisão:** onde guardar o host (por dispositivo × por loja).
  - **C** *Totem* — `appConfigProvider` mutável / `hostOverrideProvider` lido por `gogemApiProvider` (`catalog_sync.dart:43-49`); `parear` (`gogem_api.dart:63-77`) parseia `apiBase`; persistir em `kv` (chave `api_base`) e ler no boot (`device_token.dart` + `app.dart:36`); `IOClient`/`HttpClient` confiando no CA do edge; **fallback:** sem `apiBase` → nuvem.
- **Ordem:** server (retornar apiBase) → totem (persistir/usar) → confiança no CA.
- **Aceite:** totem pareado aponta pro host entregue; loja sem edge → nuvem; APK de teste comprova a troca. **UM APK.**
- **Dependências/Decisões:** onde o host mora no server; CA do edge (em dev pode ser HTTP interno).

### Fase 2 — Concentrador MVP  *(precisa do edge box)*
- **Objetivo:** serviço na caixa que recebe o totem e traduz pro Regem edge.
- **Decisão de stack:** rodar o **próprio backend GoGeM em "perfil edge"** (NestJS single-tenant, só os módulos necessários: device-auth, vendas, catálogo, clients regem) — reaproveita `DeviceTokenGuard`, `RegemSalesClient/CatalogClient/PauseClient`.
- **Entregáveis:**
  - **C** serviço na caixa (porta LAN, HTTPS+CA), `TenantContext` **fixo** (tenantId da loja).
  - **C** ingress do totem (`DeviceTokenGuard`, `X-Device-Token`).
  - **C** tradutor venda → `RegemSalesClient` apontando `localhost:3002` (**loja-token no server**).
  - **C** tradutor catálogo → `RegemCatalogClient` (`/sync/catalogo`) → `MenuVersion` local → `/catalogo/publicado`.
  - **C** tradutor pausa.
- **Ordem:** bootstrap serviço → device auth → catálogo → venda → pausa.
- **Aceite:** totem via concentrador vende → cai no **caixa** Regem local; loja-token nunca no device.
- **Dependências/Decisões:** **Fase 0 validada**; Regem edge rodando + loja-token sincronizado; como o concentrador obtém `tenantId`/loja-token (sync da nuvem).

### Fase 3 — Pagamento + espelho na nuvem
- **Objetivo:** pagamento via nuvem; `Pedido` sobe pra nuvem (relatórios/financeiro).
- **Entregáveis:**
  - **C** concentrador proxia pagamento pra **nuvem GoGeM** (`/pagamentos/point`, `/pagamentos/pix`).
  - **C** ordenação **paga → posta venda** no Regem edge com nsu/autorização.
  - **C** fila de upload do `Pedido` pra nuvem (Prisma, por loja) com retry.
  - **C** **desacoplar** `VendasService.registrarVendaTotem` (`apps/api/src/vendas/vendas.service.ts:139`): modo edge = nuvem só faz **ingest do espelho** (grava `Pedido` sem re-relay Regem).
- **Aceite:** card/PIX aprova → venda no caixa **+ pedido espelhado na nuvem**.
- **Dependências/Decisões:** Fase 2; como o concentrador autentica na nuvem (device-token × token de caixa).

### Fase 4 — Resiliência / offline
- **Objetivo:** dinheiro opera sem internet; filas duráveis.
- **Entregáveis:**
  - **C** fila local durável no concentrador (espelho de pedido + pagamento) com retry idempotente `(tenantId, idempotencyKey)`.
  - **C** dinheiro posta no Regem edge sem depender de internet; cartão/PIX aguardam egresso.
  - **C** falha-fechado se loja-token não sincronizou.
- **Aceite:** internet cai → dinheiro segue; volta → espelhos sobem sem duplicar.

### Fase 5 — Empacotar + hardening
- **Entregáveis:**
  - **V/C** concentrador no **instalador do edge Regem** (serviço na mesma caixa).
  - **C** host-por-tenant (multi-loja).
  - **V** reserva **DHCP** do edge no roteador.
  - **C/V** TLS/CA revisado + telemetria pro Console de Distribuição + doc de operação.
- **Aceite:** instalação nova sobe **edge + concentrador** juntos; multi-loja ok.

> **Encaixe das features de venda:** a **forma Dinheiro** (`docs/pagamento-dinheiro-totem.md`) e o **canal de cancelamento Regem→GoGeM** são independentes do edge — valem já no modelo nuvem e seguem valendo no edge (mesmo contrato). Podem ser feitos antes/junto da Fase 1.
