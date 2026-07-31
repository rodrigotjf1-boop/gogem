# GoGeM · API Open Delivery (provedor)

Guia para **terceiros integrarem-se a uma loja GoGeM** no padrão Open Delivery:
ler o cardápio, enviar pedidos, acompanhar status por eventos.

- **Base URL:** `https://api.gogem.com.br/open-delivery/v1`
- **Autenticação:** OAuth2 `client_credentials` (Bearer JWT, expira em 1h).
- **Dinheiro:** reais decimais (`{ "value": 29.90, "currency": "BRL" }`).
- **De-para com o PDV/ERP:** `externalCode` (= código PDV do produto/opção).

> O `clientId`/`clientSecret` é gerado pelo lojista no painel GoGeM
> (**Integrações → Open Delivery → Novo app**). O `clientSecret` aparece **uma
> única vez** — guarde-o com segurança.

---

## 1. Autenticação

```http
POST /open-delivery/v1/oauth/token
Content-Type: application/json

{ "grant_type": "client_credentials", "client_id": "od_xxx", "client_secret": "yyy" }
```
Resposta:
```json
{ "access_token": "eyJ...", "token_type": "Bearer", "expires_in": 3600 }
```
Use `Authorization: Bearer <access_token>` nas demais rotas. O token carrega a
loja (merchant) e os **escopos** concedidos ao app.

**Escopos:** `catalog:read`, `orders:read`, `orders:write`.

---

## 2. Merchant

```http
GET /open-delivery/v1/merchants/{merchantId}
Authorization: Bearer <token>
```
`merchantId` é o id da loja (o mesmo do seu token). Resposta:
```json
{ "id": "t-123", "name": "Mister Burger" }
```

## 3. Catálogo  (escopo `catalog:read`)

```http
GET /open-delivery/v1/merchants/{merchantId}/catalog
```
```json
{
  "merchant": { "id": "t-123", "name": "Mister Burger" },
  "categories": [ { "id": "c1", "name": "Burgers", "index": 0 } ],
  "items": [
    {
      "id": "p1", "name": "X-Burger", "description": "Clássico",
      "externalCode": "101", "categoryId": "c1",
      "price": { "value": 29.90, "currency": "BRL" },
      "status": "AVAILABLE", "imageUrl": "https://...", "badge": "Mais vendido",
      "optionGroups": [
        { "id": "g1", "name": "Adicionais", "min": 0, "max": 3, "index": 0,
          "options": [
            { "id": "o1", "name": "Bacon", "externalCode": "201",
              "price": { "value": 4.00, "currency": "BRL" }, "status": "AVAILABLE", "index": 0 }
          ] }
      ]
    }
  ]
}
```
`status` = `AVAILABLE` | `UNAVAILABLE` (reflete disponibilidade/pausa). O catálogo
é o **publicado** pela loja.

---

## 4. Pedidos

### Criar (ingest) — escopo `orders:write`
```http
POST /open-delivery/v1/orders
{
  "displayId": "PED-9001",
  "customer": { "name": "Ana", "document": "12345678900" },
  "items": [
    { "externalCode": "101", "name": "X-Burger", "quantity": 1,
      "price": { "value": 29.90 },
      "options": [ { "externalCode": "201", "name": "Bacon", "quantity": 1, "price": { "value": 4.00 } } ],
      "observations": "sem cebola" }
  ],
  "payments": [ { "method": "credit", "value": { "value": 33.90 } } ],
  "total": { "value": 33.90 }
}
```
- `displayId` é **idempotente**: reenviar o mesmo devolve o pedido já criado (não
  duplica). Resposta = o pedido em formato Open Delivery, `status: "PLACED"`.

### Consultar — escopo `orders:read`
```http
GET /open-delivery/v1/orders/{id}
```

### Atualizar status — escopo `orders:write`
```http
POST /open-delivery/v1/orders/{id}/status
{ "status": "CONFIRMED" }
```
Status: `CONFIRMED` → `PREPARING` → `READY` → `DISPATCHED` → `CONCLUDED`
(ou `CANCELLED`). Pedido `CONCLUDED`/`CANCELLED` não muda mais.

---

## 5. Eventos (polling)  — escopo `orders:read`

O parceiro consome os eventos por long-polling e confirma o recebimento.

```http
GET /open-delivery/v1/events/polling?limit=50
```
```json
[ { "id": "e1", "type": "ORDER_PLACED", "orderId": "o1", "createdAt": "2026-07-31T00:00:00.000Z" } ]
```
Tipos: `ORDER_PLACED`, `ORDER_STATUS_CHANGED`, `ORDER_CANCELLED`.

Depois de processar, **confirme** (senão os eventos voltam no próximo polling):
```http
POST /open-delivery/v1/events/acknowledgment
{ "ids": ["e1"] }
```
```json
{ "acknowledged": 1 }
```

> Observação de compatibilidade: o padrão Open Delivery usa `GET /events:polling`;
> aqui a rota é `GET /events/polling` (o `:polling` colide com parâmetros de rota).

---

## 6. Erros

| HTTP | Significado |
|---|---|
| 400 | Payload inválido / status não permitido |
| 401 | Token ausente/expirado ou credenciais inválidas |
| 403 | Escopo não concedido, ou `merchantId` diferente do seu app |
| 404 | Pedido inexistente |

## 7. Exemplo de fluxo (curl)
```bash
TOKEN=$(curl -s -X POST $BASE/oauth/token -H 'Content-Type: application/json' \
  -d '{"grant_type":"client_credentials","client_id":"od_xxx","client_secret":"yyy"}' | jq -r .access_token)

curl -s $BASE/merchants/$MID/catalog -H "Authorization: Bearer $TOKEN"
curl -s -X POST $BASE/orders -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @pedido.json
curl -s "$BASE/events/polling" -H "Authorization: Bearer $TOKEN"
```

> Contrato de tipos: `packages/contracts/open-delivery`.
