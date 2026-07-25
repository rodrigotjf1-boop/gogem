# packages/payment — Contrato PaymentProvider + adaptadores

Contrato único **`PaymentProvider`** (iniciar, capturar, confirmar, desfazer, cancelar, reimprimir, fechar) + **resolução de pendências idempotente no boot**. O app nunca é acoplado a uma integradora (CLAUDE.md "O que NÃO fazer").

```
payment/
├── sitef/   # SiTef/CliSiTef (Software Express-Fiserv) — prioridade 1 (S6)
├── paygo/   # PayGo Integrado (PGWebLib) — 2ª onda (S12+)
└── pix/     # PIX dinâmico via PSP (QR na tela) — Fase 1 junto com TEF
```

Regra de ouro do TEF: **nunca confirmar sem cupom persistido, nunca perder desfazimento** (§6).

> Vazio no S0. Adaptadores entram no **S6–S7** (Pagamentos).
