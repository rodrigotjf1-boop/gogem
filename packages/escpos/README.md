# packages/escpos — Driver de impressão (Dart)

Driver ESC/POS em **Dart** (consumido pelo `apps/kiosk`). Foco na **gestão de papel** — o diferencial nº 1 do produto.

- **ASB (Automatic Status Back, `GS a`)**: listener permanente de tampa/sem-papel/near-end/erro de guilhotina.
- **`DLE EOT n`**: consulta síncrona usada nos portões do fluxo (antes do pagamento).
- **Near-end**: alerta amarelo antecipado (troca de bobina).
- Alvo: Epson **TM-T88VII** (USB).

> Vazio no S0. Driver entra no **S3–S4** junto com o app do totem.
