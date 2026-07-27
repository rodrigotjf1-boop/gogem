# Kiosk Mode Android (F5) — manifest + provisionamento

## 1. App como LAUNCHER (após `flutter create`)
No `android/app/src/main/AndroidManifest.xml`, dentro da `<activity>` principal,
ADICIONE ao intent-filter existente:
```xml
<category android:name="android.intent.category.HOME"/>
<category android:name="android.intent.category.DEFAULT"/>
```
E na tag `<activity>`: `android:launchMode="singleTask" android:excludeFromRecents="true"`.
Boot direto no app: `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>`
(o HOME já garante o boot na maioria das ROMs; receiver explícito é redundante).

## 2. Provisionamento do totem (Tinker Board S rooteada — adb)
```bash
adb install -r gogem-kiosk-armeabi-v7a.apk
# definir como launcher padrão:
adb shell cmd package set-home-activity br.com.dms.gogem_kiosk/.MainActivity
# desabilitar fugas para o usuário do totem (reversível com 'enable'):
for p in com.android.launcher3 com.android.settings com.android.vending \
         com.android.chrome com.android.documentsui com.anydesk.anydeskandroid; do
  adb shell pm disable-user --user 0 $p || true
done
# permissão USB permanente para a Epson (evita o diálogo):
adb shell 'settings put global adb_enabled 1'   # manter só se necessário p/ suporte
adb reboot
```
Validação: reiniciar → o GoGeM abre sozinho; Home/Back não saem do app
(immersiveSticky + launcher); saída SOMENTE pelo painel admin (PIN) →
"SAIR DO MODO KIOSK".

## 3. Hardware novo (não-rooteado) — caminho Device Owner
```bash
adb shell dpm set-device-owner br.com.dms.gogem_kiosk/.DeviceAdminReceiver
```
(Lock Task Mode entra numa fatia futura; o launcher+watchdog acima cobre o
parque legado do piloto.)

## 4. Watchdog
Com o app como HOME, qualquer crash faz o Android reabri-lo (é o launcher).
Reforço opcional: `adb shell settings put secure immersive_mode_confirmations confirmed`.
