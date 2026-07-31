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

## Rotas (v1 — IMPLEMENTADAS)

| Método | Rota | Escopo | Descrição |
|---|---|---|---|
| `POST` | `/open-delivery/v1/oauth/token` | — | Token OAuth2 client_credentials. |
| `GET`  | `/open-delivery/v1/merchants/:id` | `catalog:read` | Dados do merchant (loja). |
| `GET`  | `/open-delivery/v1/merchants/:id/catalog` | `catalog:read` | Catálogo completo. |
| `POST` | `/open-delivery/v1/orders` | `orders:write` | Ingest de pedido (idempotente por `displayId`). |
| `GET`  | `/open-delivery/v1/orders/:id` | `orders:read` | Consulta um pedido. |
| `POST` | `/open-delivery/v1/orders/:id/status` | `orders:write` | Atualiza status. |
| `GET`  | `/open-delivery/v1/events/polling` | `orders:read` | Fila de eventos (pendentes). |
| `POST` | `/open-delivery/v1/events/acknowledgment` | `orders:read` | Confirma eventos processados. |

> O padrão usa `/events:polling`; aqui é `/events/polling` (o `:polling` colide
> com parâmetros de rota do Express).

Autenticação: OAuth2 client_credentials. O app parceiro (`OpenDeliveryApp`) tem
`clientId` público + `clientSecret` **hasheado** (bcrypt, mostrado uma vez) +
escopos, por tenant. O `/oauth/token` emite um JWT curto (1h, `aud: open-delivery`)
com o tenant do app. Guia completo: `docs/open-delivery-provider.md`.

## Mapeamento GoGeM ↔ Open Delivery

| GoGeM | Open Delivery |
|---|---|
| `Produto.externalRefs[].codigo_pdv` | `Item.externalCode` |
| `Produto.precoCentavos` | `Item.price.value` (reais) |
| `ComplementoGrupo` | `OptionGroup` |
| `ComplementoOpcao` | `Option` (com `externalCode`) |
| `Produto.disponivel` / pausa | `Item.status` (`AVAILABLE` / `UNAVAILABLE`) |
