# Publicar o totem GoGeM na Google Play

Distribuição **interna/fechada** (frota), com **In-App Update** (o app detecta
versão nova e pede autorização). Conta de desenvolvedor **organização**
(verificada por DUNS).

## Visão geral do fluxo
1. (1x) Gerar o **upload keystore** + cadastrar os **secrets** no GitHub.
2. Rodar o workflow **Build AAB (Google Play)** → baixar o `.aab` assinado.
3. No **Play Console**: criar o app, subir o `.aab` na trilha **Interna/Fechada**.
4. Atualizações: bump da versão → novo `.aab` → subir na trilha → o app
   **detecta e pede autorização** (In-App Update).

---

## 1) Upload keystore (uma vez)

No seu PC (precisa do Java/`keytool`):
```
keytool -genkey -v -keystore gogem-upload.jks -keyalg RSA -keysize 2048 -validity 9125 -alias gogem-upload
```
- Guarde a senha e o **arquivo `gogem-upload.jks`** em local seguro (backup!). Se
  perder, você perde a chave de **upload** (recuperável com o Google se usar Play
  App Signing, mas evite).
- Gere o base64 para colar no secret:
  - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("gogem-upload.jks")) > ks.b64.txt`

## 2) Secrets no GitHub
Repositório → **Settings → Secrets and variables → Actions → New repository secret**:
- `ANDROID_KEYSTORE_BASE64` = conteúdo de `ks.b64.txt`
- `ANDROID_KEYSTORE_PASSWORD` = a senha do keystore
- `ANDROID_KEY_ALIAS` = `gogem-upload`
- `ANDROID_KEY_PASSWORD` = a senha da chave (igual à do keystore se você usou a mesma)

## 3) Gerar o AAB
GitHub → **Actions → "Build AAB (Google Play)" → Run workflow** (branch `main`).
Ao terminar, baixe o artifact **`gogem-play-aab`** → `app-release.aab`.
> Esse build sai com `GOGEM_SELF_UPDATE=false` (quem atualiza é o Play) e
> `GOGEM_PAYMENT_PROVIDER=mppoint` (produção).

## 4) Play Console (conta organização)
1. **Criar app**: nome, idioma, tipo App, gratuito.
2. **Play App Signing**: aceitar (o Google gerencia a chave de assinatura; você só
   sobe assinado com o **upload key**).
3. **Teste interno** (ou fechado): criar a trilha → **Enviar** o `app-release.aab`.
4. Adicionar os **e-mails dos testadores** (ou lista) → copiar o **link de
   participação** → abrir no aparelho, aceitar, instalar pela Play.
5. Preencher o mínimo exigido: **classificação de conteúdo**, **público-alvo**,
   **segurança de dados** (o app coleta? nome/CPF do pedido — declarar), e uma
   **URL de política de privacidade**.

## ⚠️ Migração dos totens que já têm o APK sideloaded
O app do Play é assinado por outra chave (Play App Signing) → **não atualiza por
cima** do APK sideloaded (assinatura diferente). Em cada totem que já tem a
versão sideloaded:
1. **Desinstalar** o app atual (`adb uninstall br.com.dms.gogem_kiosk`).
2. Instalar pela **Play** (link da trilha interna).
3. Reparear na Frota (código de 6 dígitos).
A partir daí, as atualizações chegam pelo Play (In-App Update pede autorização).

## Atualizações futuras
1. Bump no `apps/kiosk/pubspec.yaml` (`x.y.z+N` → `+N+1`).
2. Rodar **Build AAB (Google Play)** → baixar o `.aab`.
3. Play Console → trilha interna → **Criar nova versão** → subir o `.aab` → lançar.
4. Nos totens, o app detecta e **pede autorização pra atualizar** (fluxo imediato).

## Sideload continua existindo
O workflow **Build APK (totem)** (perfil `producao`/`teste`) segue para
sideload/bancada e aparelhos **sem** Google Play — esses usam o **updater
próprio** (`/kiosk/latest`). Os dois canais coexistem: Play para quem tem GMS,
sideload+updater para quem não tem.
