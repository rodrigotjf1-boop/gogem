# Pagamento em dinheiro no totem — contrato GoGeM → Regem

> Feature: o cliente escolhe **Dinheiro** no totem; o pedido **finaliza e vai pra produção** com **pendência de pagamento**; paga no **caixa**; o atendente **confirma** → status **PAGO** → **reimpressão**. Comandas/KDS/confirmação = **Regem** (o usuário faz). GoGeM = opção no totem + cupom + relay sinalizando pendência. Plano — nada implementado.

## Descobertas (ancoradas no código)

- **Já é balcão/PDV:** o `/vendas/externa-pdv` usa `origem: 'totem'` → ramo `producao_balcao` (`backend/src/modules/producao-pedido/producao-pedido.service.ts:337`). **Não** é delivery. `plataforma` = só rótulo no KDS/cupom.
- **Endpoint é pré-pago obrigatório:** `venderTotem` valida `pagamentos[]` = total (±R$0,05) e escreve `lancamento_caixa` **entrada** na hora (`backend/src/modules/vendas/vendas.service.ts:1262-1295`). Sem estado "a receber" (`comanda.status` = aberta|fechada|cancelada, `schema.ts:1362`; `lancamento_caixa` sem coluna de status, `schema.ts:925-943`).
- **Modelo de "confirmar recebimento" já existe:** `acerto_subpdv` (`schema.ts:2900-2924`, `status: pendente|baixado|cancelado`; operador confere `recebidoCentavos` e dá baixa) — reusar essa mecânica.
- **KDS:** cada venda vira 1 `producaoPedido` (`status: recebido|preparo|pronto|entregue|cancelado`, `schema.ts:1803`), `destinoTipo:'kds'`, com `plataforma`/`senhaPlataforma` como metadados.

## Contrato do payload (GoGeM → Regem) — venda em dinheiro pendente

Reaproveita o `VendaExternaPdvDto` (`backend/src/modules/vendas/dto/venda-externa-pdv.dto.ts:55-101`) + **um sinal novo**:

```jsonc
POST /vendas/externa-pdv   (X-Loja-Token)
{
  "idempotencyKey": "<uuid do totem>",
  "itens": [ { "codigoPdv": "<produto.codigo>", "quantidade": 1, "observacao": "" } ],
  "pagamentos": [ { "forma": "dinheiro", "valor": 42.00 } ],   // venda NORMAL em dinheiro (bate com o total)
  "pagamentoPendente": true,        // ★ NOVO — INFORMATIVO: "pagar no caixa" (rótulo p/ KDS/comanda)
  "consumo": "local",
  "cpf": "",                        // opcional
  "plataforma": "GoGeM Totem",      // rótulo no KDS/cupom
  "senhaPlataforma": "123"          // nº do pedido no totem
}
```

- É uma **venda normal em dinheiro** (`forma:'dinheiro'`, soma = total) — o Regem processa como já faz. O `pagamentoPendente` é **só informativo** pra o KDS/comanda mostrarem o destaque; **não** adia o caixa.
- Resposta: `{ comandaId, senha, idempotente? }` (igual hoje).

## O que muda no GoGeM (eu)

- `FormaPagamento` enum ganha `dinheiro` (`apps/kiosk/lib/domain/order/order_models.dart:56`).
- Botão **"Dinheiro"** na tela de pagamento (`apps/kiosk/lib/features/pedido/pagamento_screen.dart:519-531`) + template GoGen — **pula a cobrança online** e finaliza direto.
- Cupom do cliente (`apps/kiosk/lib/printing/recibo.dart:7-33`): quando `dinheiro`, destaca **"EFETUAR PAGAMENTO NO CAIXA"**.
- Relay envia `forma:'dinheiro'` + `pagamentoPendente:true` (`apps/api/src/integracoes/regem/regem-sales.client.ts` + `apps/api/src/vendas/*`).

## O que muda no Regem (usuário) — modelo INFORMATIVO (leve)

A venda entra **normal** (dinheiro): comanda `fechada` + baixa estoque + KDS + `lancamento_caixa` entrada, **como já é hoje** (`vendas.service.ts:1127+`). O "a receber / PAGO" é **status informativo**, não mexe no caixa. Então:

1. **DTO:** campo opcional `pagamentoPendente: boolean` (informativo) no `VendaExternaPdvDto` — *ou* derivar de `forma === 'dinheiro'` sem novo campo.
2. **KDS/comanda de produção:** quando informativo, destacar **"PENDÊNCIA DE PAGAMENTO — VERIFICAR"**. Um status/flag no `producaoPedido` (ex.: `pagamentoConfirmado: false`).
3. **Ação "confirmar recebimento"** (só informativa): atendente confirma → status vira **PAGO** (`pagamentoConfirmado: true`) → **reimpressão** **"PEDIDO TOTEM PAGO — REIMPRESSÃO"**. **Não** cria novo lançamento de caixa (a venda já entrou).

## Cancelamentos (Regem → GoGeM) — cross-cutting (não só dinheiro)

Regra: **o cancelamento nasce no Regem** (dono de estoque/perda/caixa); o GoGeM **espelha**. O totem/GoGeM **não origina** cancel pro Regem.

- **Regem já trata** (sem mudança): estorno de **estoque**, **perda**, e **não contabilizar/estornar o caixa**.
- **Gap atual:** não existe canal de cancel Regem→GoGeM (só catálogo `/sync/regem/publicar`); o cancel do GoGeM é local-only (`apps/api/src/relatorio/relatorio.service.ts:251-277`, "Propagação ao Regem = follow-up").
- **Proposta:** inbound no GoGeM `POST /sync/regem/pedido-cancelado` (auth `x-sync-token`, por `idempotencyKey`/`regemComandaId`) → `Pedido.status='cancelado'` (+ motivo), idempotente/best-effort. Relatórios já filtram `cancelado` (`relatorio-query.dto`) → sai da receita. Vale nuvem e edge.
- **Decorrência:** o cancel originado no GoGeM (gerente-only) deve ser **gateado em loja Regem** (cancel nasce no Regem); loja sem Regem mantém o cancel local.

## Falha de pagamento → cupom "não passou" no Regem (implementado no GoGeM)

Quando o pagamento **não passa** (recusa, erro de comunicação, timeout ou **cancelamento** pelo cliente), o totem informa o Regem com o **motivo** — best-effort (o cliente vê o erro na tela do mesmo jeito). O Regem lista o **cupom "não passou" + motivo**, **sem** estoque e **sem** caixa.

**Fluxo:** totem (`_falhaPagamento`) → `POST /vendas/falha` (device-token) → o backend grava o `Pedido` como `falha` + motivo (espelho) e relata ao Regem.

**Contrato GoGeM → Regem** (endpoint que o Regem implementa):
```jsonc
POST /vendas/externa-pdv/falha      (X-Loja-Token)
{
  "idempotencyKey": "<uuid do totem>",
  "itens": [ { "codigoPdv": "...", "quantidade": 1 } ],
  "formaTentada": "credito",
  "totalCentavos": 3390,
  "senhaPlataforma": "123",
  "motivo": "Pagamento não aprovado. Tente outra forma."
}
```

**Lado GoGeM (feito):**
- Totem `reportarFalha` (`apps/kiosk/lib/data/api/gogem_api.dart`) — best-effort; sem device-token não tenta.
- Backend `POST /vendas/falha` (`vendas.controller.ts`) + `VendasService.registrarFalhaTotem` (grava `Pedido` `falha` + motivo) + `RegemSalesClient.relatarFalha` (relata; **404 até o Regem criar o endpoint = ignorado**, best-effort).

**Lado Regem (usuário):** criar `POST /vendas/externa-pdv/falha` → cupom "não passou" + motivo, sem caixa/estoque.

**Default:** reporta **erros E cancelamentos** (o `motivo` distingue). Se quiser só erros, é 1 ajuste no `_falhaPagamento`.

## Decisões de desenho

- **Venda em dinheiro entra normal** (caixa registra no fechamento do totem); **"a receber"/"PAGO" = informativo** pro atendente conferir/entregar. Sem adiamento de caixa, sem `acerto`.
- **Estoque baixa na hora** (a comida é feita).
- **Idempotência** intacta (`(tenantId, idempotencyKey)`).
- ⚠️ *Implicação (ciente):* se o cliente **desistir sem pagar**, a venda já entrou no caixa (a baixa/estorno seria manual, via cancelamento). Modelo aceito por simplicidade.
- Vale nos **dois modelos** (nuvem hoje e edge amanhã) — mesmo contrato `/vendas/externa-pdv`.
