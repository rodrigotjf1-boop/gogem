# Instalar e testar o GoGeM (piloto)

Guia prático para colocar o **backend + admin no ar** e **instalar o app do totem**
nos Tinker Board. Runbook detalhado de deploy: `docs/deploy-staging-gogem.md`.

---

## 0. Acessos que você precisa ter em mãos

| Acesso | Para quê |
|---|---|
| **EasyPanel** (VPS) | Subir Postgres + API + admin |
| **DNS do `gogem.com.br`** | Criar `api.` e `app.` |
| **GitHub** (repo `gogem`) | Disparar o build do APK (aba Actions) |
| **Totens** Tinker Board S (Android 11) | Instalar o APK (ADB ou pen drive) |
| *(opcional)* usuário admin no **Regem** do cliente | Gerar o token de integração p/ importar o cardápio |

---

## 1. Backend (API + Postgres) — EasyPanel

No projeto `gogem-staging` (referência completa: `docs/deploy-staging-gogem.md`):

1. **`gogem-db`** — Postgres 16.
2. **`gogem-api`** — build pelo `apps/api/Dockerfile`, **contexto = raiz do monorepo**.
   Variáveis de ambiente:
   ```
   DATABASE_URL=postgres://<user>:<senha>@gogem-db:5432/gogem   # host interno do EasyPanel
   JWT_SECRET=<gere um segredo forte>
   PORT=3000
   NODE_ENV=production
   CORS_ORIGIN=https://app.gogem.com.br
   # opcional (integração Regem — §6):
   REGEM_API_BASE=
   REGEM_SYNC_TOKEN=
   ```
   > O Dockerfile já roda `prisma migrate deploy` no boot (cria as tabelas).
3. **Domínio** `api.gogem.com.br` (TLS) + **DNS** A record → IP da VPS.
4. **Smoke:** `https://api.gogem.com.br/api/v1/health` deve responder `{"status":"ok"}`.

> Redis, MinIO/S3 podem ficar vazios por ora (o código ainda não os usa).

---

## 2. Admin (retaguarda)

**Opção A — testar já (mais rápido):** rode local apontando para a API publicada:
```bash
# na raiz C:\GoGeM
$env:VITE_API_URL="https://api.gogem.com.br/api/v1"   # PowerShell
corepack pnpm@9 -F @gogem/admin dev                    # abre em localhost:5173
```

**Opção B — hospedar** (`app.gogem.com.br`): serviço no EasyPanel buildando
`apps/admin/Dockerfile`, **contexto = raiz**, com build-arg:
```
VITE_API_URL=https://api.gogem.com.br/api/v1
```
> O Vite **bakeia** a URL no build — para trocar a API, rebuild a imagem.
> E garanta que o `CORS_ORIGIN` da API (§1) seja `https://app.gogem.com.br`.

---

## 3. Conta do piloto + cardápio + publicação

No admin (local ou hospedado):
1. **Registrar** → cria empresa + presidente (login por e-mail/senha).
2. **Catálogo** → monte categorias/produtos (ou **Importar do Regem**, §6).
   Cada produto precisa de **código PDV** para casar com o Regem.
3. **Publicar** → gera a **v1** do cardápio (é o que o totem baixa).

---

## 4. Gerar o APK do totem (sem SDK local)

Na aba **Actions** do GitHub → workflow **"Build APK (totem)"** → **Run workflow**:
- `api_url`: `https://api.gogem.com.br/api/v1`
- `dev_jwt`: um JWT de gestor (veja §5)

Ao terminar, baixe o artifact **`gogem-totem-apk`**. Os Tinker Board S são
**ARM 32-bit** → use o **`app-armeabi-v7a-release.apk`**.

---

## 5. JWT do totem (temporário)

O app se autentica com um JWT de gestor **injetado no build** (ponte até o
pareamento de dispositivo existir). Para obtê-lo:
```bash
curl -X POST https://api.gogem.com.br/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"<gestor>","senha":"<senha>"}'
# copie o campo "access_token"
```
> ⚠️ **Esse JWT expira em ~12h.** Serve para uma sessão de teste; se expirar,
> gere outro e rebuild o APK. A solução definitiva (token de dispositivo que não
> expira) é a **frente de pareamento** — ver "Próximas frentes".

---

## 6. (Opcional) Importar o cardápio do Regem

1. No **Regem**, cadastre um `equipamento` do tipo **`servidor_local`** no tenant
   do cliente e copie o `token`.
2. Na API GoGeM (§1), preencha `REGEM_API_BASE` e `REGEM_SYNC_TOKEN=<token>` e
   redeploy.
3. No admin → **Importar** → **Importar do Regem** (casa por código PDV; aditivo).
4. **Publique** de novo (§3) para o totem receber.

---

## 7. Instalar no Tinker Board S

1. No Android do totem: **Configurações → Segurança → Fontes desconhecidas** (ligar).
2. Instale o APK:
   - via ADB (do seu PC): `adb install -r app-armeabi-v7a-release.apk`
   - ou copie o `.apk` para o totem (pen drive/rede) e abra para instalar.
3. Abra o **GoGeM**.
   > O **modo quiosque** (launcher próprio / Device Owner) é provisionamento do
   > device, à parte — para **testar o fluxo**, abrir o app manualmente basta.

---

## 8. Roteiro de teste (fluxo ponta a ponta)

1. **Descanso** → toque → **catálogo** (baixa a versão publicada).
2. Montar pedido → **CPF opcional** → **pagamento (mock)** → **confirmação com senha**.
3. **Gestão de papel:** tire o papel da impressora → o totem **bloqueia antes do
   pagamento** e sinaliza; recoloque → libera. (Diferencial nº 1.)
4. **Portão admin:** 5 toques no canto superior esquerdo da tela de descanso →
   PIN (dev `4590`) → painel (testar impressora, reimprimir fila, sincronizar).

---

## Próximas frentes (para o piloto ficar redondo)

- **Pareamento de dispositivo** — o totem troca um código por um **token que não
  expira** (backend pronto; falta a tela no kiosk + gerar o código no admin/Frota).
  Elimina a dependência do JWT de 12h.
- **Frota** (admin PR E) — listar totens, status/telemetria, gerar código de
  pareamento, ligar/desligar módulos.
- **Modo quiosque** — launcher + watchdog (legado) / Device Owner (hardware novo).
- **TEF/fiscal** — hardware + homologação (fora do piloto de fluxo).
