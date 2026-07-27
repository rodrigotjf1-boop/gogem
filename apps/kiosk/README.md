# GoGeM Kiosk (`apps/kiosk`) — Fatias 1–3

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

## Fatia 2 — sync do cardápio (offline-first)
- `data/api/gogem_api.dart` — `GET /catalogo/publicado?desde=<versao>` (JWT dev
  via `GOGEM_DEV_JWT` até o pareamento §7.1 existir);
- `data/db/kiosk_database.dart` — SQLite = fonte da verdade local
  (`menu_snapshot` guarda o corpo bruto por versão; retenção das 3 últimas);
- `data/catalog/` — modelos com parsing defensivo, repositório e
  `CatalogSyncNotifier` (agendador 60s com backoff exponencial até 10min;
  falha de rede NUNCA apaga o snapshot local);
- Tela de catálogo real: chips de categoria + grade de produtos + selo de sync.

Rodar apontando para o staging:
```bash
flutter run \
  --dart-define=GOGEM_API_URL=https://api.gogem.com.br/api/v1 \
  --dart-define=GOGEM_DEV_JWT=<access_token do /auth/login de staging> \
  --dart-define=GOGEM_HW_PROFILE=low
```

## Fatia 3 — fluxo de pedido (pagamento MOCK)
descanso → catálogo → produto (grupos com min/max/obrigatorio; `obrigatorio`
com min 0 exige 1; max=1 vira rádio) → carrinho (qtd, totais em centavos) →
CPF opcional (numpad próprio + validação de DV) → pagamento mock
(crédito/débito/pix) → confirmação: robô "imprime" (paperExtent 0→1, animação
única) + SENHA gigante + auto-retorno em 8s.

Todo pedido nasce com **UUID v4** e entra na fila local `pedidos_locais`
(`pendente_envio`) com **senha sequencial diária** — a F6 drena a fila para o
backend com a mesma chave (idempotência). O JSON do pedido referencia SEMPRE
`codigo_pdv` (nunca id interno).

## Próximas fatias
F4 ESC/POS com portões de papel (o portão entra ANTES do pagamento) ·
F5 kiosk mode + painel admin real · F6 venda idempotente no backend/TEF real.
