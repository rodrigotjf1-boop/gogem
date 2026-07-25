# apps/kiosk — App de totem (Flutter)

Flutter para **Android** (armeabi-v7a/arm64) e **Windows**. UI de autoatendimento em modo quiosque, com impressão ESC/POS e TEF.

- **Offline-first**: SQLite é a verdade local; fila de sync com backoff (CLAUDE.md §7).
- **Gestão de papel** (diferencial nº 1): ASB + `DLE EOT` nos portões do fluxo — nunca cobrar sem poder concluir.
- **Performance**: alvo Tinker Board S (2GB, 32-bit) — degradação elegante, WebP pré-dimensionado, zero jank.
- **Impressão/pagamento**: via `packages/escpos` e `packages/payment` (contrato `PaymentProvider`), nunca acoplado a uma integradora.

> Vazio no S0. Bootstrap do app entra no **S3–S4** (App Totem núcleo). Ver `docs/roadmap-execucao-gogem.md`.
