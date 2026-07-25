# integrations/regem — Cliente da API do Regem

Cliente da API do Regem + **de-para de códigos PDV**. O contrato completo, mapeado do código-fonte real do Regem, está em [`ENDPOINTS.md`](ENDPOINTS.md).

## Pontos-chave do contrato

- **Código PDV = `produto.codigo`** no Regem (chave `(tenant_id, codigo)`). É o alvo do `external_refs[] {sistema:"regem", codigo_pdv}`.
- **Auth de serviço**: sem `client_credentials`; usar o token de dispositivo **`X-Sync-Token`** (tenant derivado do equipamento). Evoluir para client-credentials na API pública.
- **Leitura de catálogo**: `GET /api/v1/produtos` (traz `codigo`); o menu público tokenizado **não** expõe o código.
- **Preços em reais decimais** no Regem → nosso canônico é centavos; converter na borda.
- **Lançamento de venda paga por `codigo_pdv`** é a lacuna #1 (L-VEN-1) — endpoint novo no Regem (backlog do Regem, §9 do ENDPOINTS.md).

> `ENDPOINTS.md` é versionado por commit-base do Regem. Regerar quando o Regem evoluir os endpoints de catálogo/venda.
