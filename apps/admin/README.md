# apps/admin — Retaguarda (React + Vite)

SPA React + Vite + Tailwind + shadcn/ui. Backoffice: cardápio, relatórios, painel de frota, fila de reimpressão, conflitos de sincronização de catálogo.

- Monta e publica o cardápio da loja (categorias, produtos, combos, complementos, preços, disponibilidade, fotos).
- Painel de **frota/telemetria** (heartbeat, status de papel/pinpad, OTA).
- **De-para PDV**: gerencia `external_refs[] {sistema, codigo_pdv, loja}` por produto.

> Vazio no S0. CRUD de catálogo entra no **S1–S2**; painel de frota no **S5**.
