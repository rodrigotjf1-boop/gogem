# Instalação e configuração do totem GoGeM

> Procedimento completo para colocar um totem GoGeM em operação: da nuvem ao
> pinpad. Siga na ordem. Cada passo diz **onde** fazer e **como confirmar** que
> deu certo.

## 0. Visão geral

O totem é um APK Android que fala com:

- a **nuvem GoGeM** (`api.gogem.com.br`) — catálogo, pedidos, pareamento, PIX;
- o **Regem** (opcional) — importa o cardápio e recebe as vendas;
- o **Mercado Pago** (opcional) — PIX por QR;
- o **pinpad Elgin** (opcional) — cartão crédito/débito pelo TEF.

Pagamento é modular (contrato `PaymentProvider`): **PIX pelo PSP** e **cartão
pelo TEF** convivem e ligam/desligam por configuração.

---

## 1. Pré-requisitos

**Hardware**

- Tablet/totem Android (ARM64 recomendado; ARM 32 suportado).
- (Cartão) Pinpad homologado Elgin — ex.: **Gertec PPC930** — + app **IDH
  ElginTef** instalado no aparelho.
- (Impressão) Impressora térmica ESC/POS (USB/rede), se for imprimir cupom.

**Contas / acessos**

- Login no **admin** do GoGeM (`app.gogem.com.br`), perfil gerente+.
- (Regem) token do equipamento **servidor_local** no Regem.
- (PIX) **Access token** do Mercado Pago da loja.
- (Cartão) terminal Elgin **ativado** (CNPJ credenciado no SiTef/adquirente).

---

## 2. Nuvem (uma vez por ambiente)

No serviço **`gogem-api`** (EasyPanel):

1. **Migrations** — aplicar as pendentes no `gogem-db`, em especial:
   - `20260801000000_kiosk_release` (auto-update do APK);
   - `20260804000000_pix_charge` (PIX).
2. **Variáveis de ambiente** (só o que usar):
   - `CORS_ORIGIN=https://app.gogem.com.br` (a API já libera `*.gogem.com.br`).
   - `KIOSK_RELEASE_TOKEN=<segredo forte>` — habilita publicar releases do APK.
   - `GOGEM_PSP` / `MERCADOPAGO_ACCESS_TOKEN` — **não precisa**: o PIX é
     configurado por loja no admin (env é só fallback de dev).
3. **Confirmação:** `GET https://api.gogem.com.br/api/v1/health` responde ok.

---

## 3. Build/obtenção do APK

O APK já sai apontando para produção (`api.gogem.com.br`). Escolha os
`--dart-define` conforme o que a loja usa:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=GOGEM_API_URL=https://api.gogem.com.br/api/v1 \
  --dart-define=GOGEM_PAYMENT_PROVIDER=elgin   # só se for usar cartão no pinpad
```

- `GOGEM_PAYMENT_PROVIDER`: `fake` (padrão, bancada) · `elgin` (cartão no pinpad).
  **PIX independe disso** (vai sempre pelo PSP).
- Artefato: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- **Confirmação:** instala e abre na tela de descanso (sem "sem conexão").

> Depois do primeiro APK instalado, as próximas versões podem ir por
> **auto-update** (§8) — sem reinstalar na mão.

---

## 4. Pareamento do totem

1. **Admin → Auto atendimentos** → cadastrar totem → gera um **código de 6
   dígitos** (vale 15 min).
2. **No totem:** abra o portão admin (5 toques no canto superior esquerdo da tela
   de descanso) → digite o código.
3. **Confirmação:** o totem sai do "aguardando pareamento" e sincroniza o
   cardápio (badge de sync no catálogo).

---

## 5. Integração com o Regem (opcional)

Para importar o cardápio e mandar as vendas do totem ao Regem.

1. No **Regem**: Gestão → Equipamentos & Apps → cadastre/pegue o **Servidor
   local (edge)** e copie o **token**.
2. No **admin GoGeM → Integrações → Regem → Configurar**:
   - URL da API: `https://api.dmsregem.com/api/v1`
   - Token de sincronização: o token do servidor_local
   - marque **Integração ativa** → **Salvar**.
3. **Testar conexão** → "Conexão ok — N produto(s)". Depois **Importar catálogo**
   (traz produtos + imagens).
4. **Confirmação:** os produtos (com foto) aparecem no Catálogo do totem.

---

## 6. PIX (Mercado Pago) — por loja

1. **Admin → Integrações → Mercado Pago (PIX) → Configurar**:
   - **Access token** (produção `APP_USR-…`; teste `TEST-…`) → **Salvar** →
     **Ativar**.
2. **Testar conexão** → "Conexão ok — conta X".
3. **Webhook (recomendado):** no painel do Mercado Pago, aponte as notificações
   de `payment` para `https://api.gogem.com.br/api/v1/pagamentos/pix/webhook`.
4. **Confirmação:** no totem, escolha PIX → aparece o QR; pague → o totem detecta
   a aprovação (polling + webhook) e conclui o pedido.

> **Sem configurar**, o PIX roda em **sandbox** (QR de teste que aprova sozinho
> em ~6s) — ótimo para validar o fluxo antes de ligar a conta real.

---

## 7. Cartão pelo pinpad (Elgin TEF) — opcional

1. **Instale o app IDH ElginTef** no totem (loja Elgin / APK do IDH).
2. **Configure e ative o terminal** (uma vez), pela interface do IDH ou pelos
   intents `configurar` + `ativar` (CNPJ credenciado).
3. **APK do totem** buildado com `--dart-define=GOGEM_PAYMENT_PROVIDER=elgin`
   (§3).
4. **Confirmação:** no totem, escolha **Crédito/Débito** → o IDH assume a tela e
   pede o cartão no pinpad; ao aprovar, o totem conclui o pedido.

**Teste da tomada (recomendado antes de operar):** arranque o cabo do pinpad no
meio da transação → o totem cancela e volta ao descanso, sem pedido órfão.

> A validação real do cartão **exige o PPC930 + IDH ativado**. Sem eles, a forma
> de cartão responde indisponível/cancelado.

---

## 8. Auto-update do APK (opcional)

Para não reinstalar na mão a cada versão.

1. **Admin → Auto atendimentos → Atualizações do totem**: cole o
   `KIOSK_RELEASE_TOKEN` (§2), suba o `.apk`, informe versionCode/versionName →
   **Publicar**.
2. O totem verifica na tela de descanso (a cada 3h), baixa, confere o `sha256` e
   instala. Em totem **device owner**, a instalação é **silenciosa**.
3. **Confirmação:** um totem em versão anterior atualiza sozinho para a publicada.

---

## 9. Aparência (tema da loja)

**Admin → Configurações → Aparência do totem**: cores, logo, tela de descanso e
**Estilo do totem** (Padrão / Brasa / Burger House — este aplica a paleta em 1
clique). Aplica no próximo sync do totem.

---

## 10. Checklist final

- [ ] `gogem-api` no ar, migrations aplicadas.
- [ ] APK instalado e **pareado** (sincroniza o cardápio).
- [ ] Catálogo com produtos e fotos (Regem importado, se usar).
- [ ] PIX: "Conexão ok" + QR aparece no totem (ou sandbox aprovando).
- [ ] Cartão (se usar): IDH ativado + crédito/débito concluindo no pinpad.
- [ ] Teste ponta a ponta: pedido → pagamento → cupom/senha → aparece no Regem
      (se integrado).

Pronto: totem em operação.
