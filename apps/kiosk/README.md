# GoGeM Kiosk (`apps/kiosk`) — Fatia 1: andaime

App do totem em Flutter (Android armeabi-v7a/arm64 + Windows), Riverpod, tema
dark "game menu", perfis de hardware para o RK3288 e navegação base
(descanso → catálogo, portão admin com teclado embaralhado).

## Gerar as pastas de plataforma (uma vez, na sua máquina)
Este diretório contém só o código Dart + assets. Para criar `android/`, `windows/` etc.:
```bash
cd apps/kiosk
flutter create --org br.com.dms --project-name gogem_kiosk --platforms=android,windows .
```
Depois aplique no `android/app/build.gradle` (dentro de `android { defaultConfig { ... } }`):
```gradle
ndk { abiFilters "armeabi-v7a", "arm64-v8a" }
minSdkVersion 24
```
(A Tinker Board S roda o APK armeabi-v7a; hardware novo usa arm64.)

## Rodar
```bash
flutter pub get
flutter analyze && flutter test
flutter run --dart-define=GOGEM_API_URL=https://api.gogem.com.br/api/v1 \
            --dart-define=GOGEM_HW_PROFILE=low        # simular Tinker Board
```
`GOGEM_DEV_JWT` (temporário até o pareamento §7.1): token de staging para as
próximas fatias de sync.

## Estrutura
```
lib/core/theme       tema/paleta oficial da marca
lib/core/hardware    HardwareCaps (low = RK3288: sem blur/partículas, anim 0.6x)
lib/core/config      AppConfig via --dart-define (zero segredo no repo)
lib/core/router.dart go_router (navegação interna, sem deep links)
lib/features/…       descanso (robô animado) · catalogo (placeholder F2/F3) · admin (PIN embaralhado)
lib/widgets/gogem_robot.dart  o Robô-Totem em CustomPainter (paperExtent/blink animáveis)
```

## Próximas fatias
F2 sync do cardápio (SQLite offline-first) · F3 fluxo de pedido · F4 ESC/POS
com portões de papel · F5 kiosk mode + painel admin real · F6 lançamento da
venda idempotente.
