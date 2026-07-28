# Contrato Open Delivery (GoGeM API aberta)

Especificação inicial do contrato **Open Delivery** que o GoGeM expõe/consome como
conector — parte da estratégia de API aberta (Fase 2). Aqui vive o *contrato*
(tipos + descrição das rotas); a implementação do conector no backend é um
follow-up (o conector aparece como "em breve" na tela de Integrações até então).

> Fonte de verdade da API interna continua sendo o OpenAPI gerado por `apps/api`.
> Este pacote documenta a **superfície pública** para terceiros integrarem-se ao
> GoGeM no padrão Open Delivery.

## Modelo de entidades

Espelha o padrão de mercado (Open Delivery / iFood Catalog): a árvore de catálogo
é `Merchant → Category → Item → OptionGroup → Option`, e o de-para com o PDV/ERP
usa **`externalCode`** (equivalente ao nosso `codigo_pdv`). Dinheiro em **reais
decimais** no padrão Open Delivery (o GoGeM converte de/para centavos na borda,
como já faz com o Regem — ver `fix(venda)`).

Ver `open-delivery.types.ts` para os tipos.

## Rotas previstas (v1, a implementar)

| Método | Rota | Descrição |
|---|---|---|
| `GET`  | `/open-delivery/v1/merchants/:id` | Dados do merchant (loja). |
| `GET`  | `/open-delivery/v1/merchants/:id/catalog` | Catálogo completo (categorias/itens/opções). |
| `POST` | `/open-delivery/v1/orders` | Recebe um pedido (ingest) para materializar no GoGeM. |
| `POST` | `/open-delivery/v1/orders/:id/status` | Atualiza status do pedido (confirmado, pronto, cancelado…). |
| `GET`  | `/open-delivery/v1/events:polling` | Long-polling de eventos (pedido novo/cancelado). |

Autenticação: OAuth2 client-credentials (`clientId`/`clientSecret` por integração,
guardados em `Integracao.config` do tenant, segredo mascarado). Escopo por tenant.

## Mapeamento GoGeM ↔ Open Delivery

| GoGeM | Open Delivery |
|---|---|
| `Produto.externalRefs[].codigo_pdv` | `Item.externalCode` |
| `Produto.precoCentavos` | `Item.price.value` (reais) |
| `ComplementoGrupo` | `OptionGroup` |
| `ComplementoOpcao` | `Option` (com `externalCode`) |
| `Produto.disponivel` / pausa | `Item.status` (`AVAILABLE` / `UNAVAILABLE`) |
