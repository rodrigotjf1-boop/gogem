# Pagamento em dinheiro no totem + reporte de falha — GoGeM ↔ Regem

> Estado: **lado GoGeM implementado** (PR #130). O totem ganha a forma **Dinheiro**
> (pago no caixa) e passa a informar o Regem em **dois momentos distintos**, cada um
> num endpoint próprio. O lado Regem (endpoints receptores) é do usuário.

## Roteamento (o que o GoGeM envia)

O totem sempre fala com o **backend GoGeM** (`POST /vendas`, device-token). O backend
decide o destino no Regem conforme o caso:

| Momento | Endpoint no Regem (X-Sync-Token) | Efeito no Regem |
|---|---|---|
| **Dinheiro** (cliente escolheu) | `POST /delivery/totem-dinheiro` | Retirada **"Totem GoGeM" a receber**, cobrada no balcão (finaliza lá). **Sem caixa/estoque até pagar.** |
| **Falha** no pagamento (erro/recusa/timeout/cancelamento) | `POST /vendas/externa-pdv/falha` | Cupom **"falha no pagamento"** + motivo. Sem caixa/estoque. |
| **Cartão/PIX aprovado** | `POST /vendas/externa-pdv` (já existia) | Venda fechada normal (caixa/estoque/KDS). |

Ambos os novos são **idempotentes** por `idempotencyKey` e **best-effort** (404 até o
endpoint subir = ignorado; nada quebra no totem).

### Dinheiro → `POST /delivery/totem-dinheiro`
```jsonc
{
  "idempotencyKey": "<uuid do totem>",
  "itens": [ { "codigoPdv": "...", "quantidade": 1 } ],
  "cliente": "Fulano",         // opcional
  "senhaPlataforma": "123",    // opcional (nº do pedido no totem)
  "totalCentavos": 3390        // opcional (o Regem recalcula pelo preço do servidor)
}
```
Auth = `X-Sync-Token` (o mesmo do `/delivery/ingest`). Resposta: parse defensivo — se
vier `{ comandaId, senha }`, o totem mostra a senha; senão usa a **senha local**.

### Falha → `POST /vendas/externa-pdv/falha`
```jsonc
{
  "idempotencyKey": "<uuid do totem>",
  "itens": [ { "codigoPdv": "...", "quantidade": 1 } ],
  "formaTentada": "credito",
  "totalCentavos": 3390,
  "senhaPlataforma": "123",
  "motivo": "Pagamento não aprovado. Tente outra forma."
}
```
Reporta **erros E cancelamentos** (o `motivo` distingue).

## Lado GoGeM (implementado — PR #130)

**Totem (Flutter):**
- `FormaPagamento.dinheiro` + botão **Dinheiro** (telas padrão + GoGen) — finaliza **sem cobrar**.
- Cupom do cliente: destaque **"EFETUAR PAGAMENTO NO CAIXA"** (`recibo.dart`).
- Confirmação: **contador de 40s** (auto-retorno) + box **"PAGUE NO CAIXA PARA RETIRAR"** no dinheiro.
- `reportarFalha` best-effort no `_falhaPagamento` (erro/cancelamento).

**Backend (NestJS):**
- `VendasService.registrarVendaTotem`: se `forma == 'dinheiro'` → `relayDinheiro` → `RegemSalesClient.lancarTotemDinheiro` (`/delivery/totem-dinheiro`, best-effort). Senão, `/vendas/externa-pdv`.
- `POST /vendas/falha` → `registrarFalhaTotem` → `RegemSalesClient.relatarFalha` (`/vendas/externa-pdv/falha`).
- `Pedido` (espelho) fica `enviado` no sucesso / `falha` + `erro` na falha do relay.

## Lado Regem (usuário)

- `POST /delivery/totem-dinheiro` → cria a retirada "Totem GoGeM" a receber; cobra/finaliza no balcão.
- `POST /vendas/externa-pdv/falha` → lista o cupom "falha no pagamento" + motivo.

## Cancelamentos (Regem → GoGeM) — cross-cutting (ainda pendente)

Regra: **o cancelamento de um pedido já criado nasce no Regem** (dono de estoque/perda/caixa); o GoGeM **espelha**. O totem/GoGeM **não origina** cancel de pedido pro Regem.
- **Gap atual:** não existe canal de cancel Regem→GoGeM (só catálogo `/sync/regem/publicar`).
- **Proposta:** inbound no GoGeM `POST /sync/regem/pedido-cancelado` (`x-sync-token`, por `idempotencyKey`/`regemComandaId`) → `Pedido.status='cancelado'`. Relatórios já filtram `cancelado`.

## Decisões

- **Dinheiro = retirada "a receber"** (NÃO venda fechada) → financeiro correto: só entra no caixa quando pago no balcão.
- **Best-effort** nos dois relays novos (o cliente já tem o cupom / vê o erro na tela). ⚠️ *Tradeoff:* uma falha transitória do relay do dinheiro não tem auto-retry — nesse caso raro o pedido não aparece na Retirada do Regem. Se quiser garantia (retry via fila do totem), é trocar o best-effort por re-throw.
- Idempotência dupla `(tenantId, idempotencyKey)` local + dedupe no Regem.
- Vale nos **dois modelos** (nuvem hoje, edge amanhã) — mesmos contratos.
