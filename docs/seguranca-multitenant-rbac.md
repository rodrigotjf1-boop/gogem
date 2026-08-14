# Segurança — isolação multi-empresa, RBAC e login

Referência da postura de segurança do GoGeM. Auditado e endurecido em ago/2026
(PRs #123–#125). **Regra de ouro:** a fronteira de segurança é o **Tenant**
(empresa/loja). Nenhuma empresa acessa dados de outra.

## Modelo de tenancy

- **Tenant** = a conta = uma **loja** (o catálogo é por tenant → 1 tenant = 1 loja).
- **Unidade** = loja dentro do tenant (usuários/dispositivos carregam `unidadeId`).
- Empresa Regem com N unidades (matriz+filiais) = **N tenants GoGeM**, cada um
  ligado à sua unidade pelo token de auto-atendimento. Ver
  `docs/integracao-token-loja.md` (se existir) e a memória do projeto.

## Camadas de isolação (todas ativas)

1. **ORM fail-closed** — `tenantScopeMiddleware` injeta `tenantId` em TODA
   leitura/escrita dos modelos escopados; **sem tenant no contexto →
   `ForbiddenException`**. Cobertura completa: todo modelo com dado de empresa
   está em `TENANT_SCOPED_MODELS`. Fora do set, de propósito: `Tenant` (raiz),
   `KioskRelease`/`WindowsBuild` (globais do produto), `OrgUsuario` (Distribuição).
2. **Origem do tenant confiável** — vem do **JWT assinado** (`payload.tenant`) ou
   do **device token** (`X-Device-Token` → `dispositivo.tenantId`), **nunca** do
   body/query. O `TenantContextInterceptor` embrulha a request no `TenantContext`.
3. **Cross-tenant só na Distribuição (DMS)** — `OrgAuthGuard` + `runAsSystem`,
   separado do login do cliente. Os `runAsSystem` em código de cliente são só
   lookup de bootstrap (login por e-mail, pareamento por código) que re-escopam.

## RBAC — hierarquia e cobertura

Papéis: `presidente > gerente > supervisao > execucao` (do DB, no JWT). O
`RolesGuard` é **hierárquico** (`@Roles(mínimo)`).

| Área | Papel mínimo (mutação) |
|---|---|
| Catálogo (categoria, produto, complemento, cardápio, aparência, publicar) | gerente |
| Integrações (Regem/Open Delivery), dispositivos, mídia | gerente |
| Relatórios + cancelar pedido | gerente |
| Auditoria (leitura) | **presidente** |
| Point: `devices`/`journal` | gerente · cobrança/status/cancelar | device token |
| Distribuição (Console DMS) | login org separado (OrgAuthGuard) |
| Totem (venda, telemetria, PIX/Point, kiosk/latest) | device token |
| Webhooks (Regem inbound, MP) | token do recurso + re-escopo por tenant |
| Público: `login`/`register`/`parear` | sem papel, **rate-limited 10/min** |

## Superfície pública e abuso

- `ThrottlerGuard` global (120/min) + throttle apertado (10/min) em
  login/register/parear. Código de pareamento: 6 dígitos `randomInt` + TTL 15 min.
- **Helmet** ativo; **CORS** por allowlist (não `*`); **Swagger** só com
  `SWAGGER_ENABLED=true`.

## Guardas de regressão (travam o futuro)

- `test/tenant-isolation.spec.ts` — falha se um model novo não for classificado
  (escopado ou global explícito) e exige `tenantId` nos escopados.
- `test/no-tenant-input.spec.ts` — falha se algum DTO/endpoint aceitar
  `tenantId`/`empresaId` do cliente.
- `test/rbac-coverage.spec.ts` — falha se uma mutação atrás do JwtAuthGuard não
  tiver `@Roles`.
- `test/tenant-scope.spec.ts` — comportamento do middleware (injeção + fail-closed
  + runAsSystem).

## Auditoria (Fase 5)

Trilha **append-only** (`Auditoria`, tenant-scoped): quem (usuário/papel), ação,
recurso, quando. `AuditoriaService.registrar()` lê o ator do `TenantContext`
(nada do cliente), best-effort (nunca derruba a ação). Leitura: `GET /auditoria`
(presidente). Ligado hoje em: cancelar pedido, salvar/ativar integração.
**Ampliar** para: pausar/excluir categoria, resolver conflito do espelho, publicar
cardápio, aparência, acesso da Distribuição a uma loja.

## Pendências / opcionais

- **MFA (TOTP) no login do Console da Distribuição** (Regem já tem o padrão).
- Ampliar os pontos auditados (lista acima).
- LGPD: política de retenção/expurgo de CPF/nome do cliente.
- Painel "rede/grupo" consolidado (dono com várias contas GoGeM) — só se um
  cliente real precisar; hoje o modelo é 1 conta GoGeM por loja.
