# Deploy Staging — GoGeM API (EasyPanel) · Runbook v1

Objetivo: colocar a API no ar em staging, com banco real, integração Regem funcional e smoke test verde. Tempo estimado: 1h30 (sem imprevistos). Pré-requisito: PRs #2→#6 mergeados **na ordem da pilha** na main (o PR de deploy é empilhado no #6, então entra junto).

> **Atualizações já aplicadas neste PR de deploy** (não precisa refazer):
> - **Migration inicial versionada** em `apps/api/prisma/migrations/` (gerada contra o schema completo via `prisma migrate diff --from-empty`). §0 abaixo já está feito.
> - **CORS** habilitado na API (`main.ts` + var `CORS_ORIGIN`) — sem isso o admin (outro domínio) quebra.
> - **`prisma` movido para `dependencies`** — sobrevive ao `prune --prod` do Dockerfile, para o `migrate deploy` funcionar em runtime.
> - **`.dockerignore`** na raiz + Dockerfile com `COPY . .` — o `--frozen-lockfile` não quebra quando o admin entra no workspace.

---

## 0. Migrations — JÁ FEITO neste PR ✅

A migration inicial já está versionada em `apps/api/prisma/migrations/20260725000000_init/` (+ `migration_lock.toml`). Em staging/produção usamos sempre `prisma migrate deploy` (nunca `db push` com dados) — o Dockerfile roda isso a cada subida.

Se no futuro alterar o schema, gere a nova migration antes de subir:
```bash
# com um Postgres local/descartável apontado no .env
pnpm -F @gogem/api exec prisma migrate dev --name <mudanca>
git add apps/api/prisma/migrations && git commit -m "chore(prisma): <mudanca>"
```

## 1. EasyPanel — projeto `gogem-staging` (separado do de produção futuro)

Criar os serviços nesta ordem (nomes exatos, facilita os templates):

| Serviço | Tipo | Config |
|---|---|---|
| `gogem-db` | Postgres 16 | volume persistente; senha forte; NÃO expor porta pública |
| `gogem-redis` | Redis 7 | sem exposição pública |
| `gogem-media` | MinIO | volume; console interno; criar bucket `gogem` |
| `gogem-api` | App (Git) | build do monorepo (ver §2); domínio `api-stg.gogem.com.br` com TLS |

Domínio: crie o subdomínio `api-stg` no DNS do domínio que você está registrando apontando para a VPS; o proxy do EasyPanel emite o certificado.

## 2. Build da API no EasyPanel (monorepo pnpm)

App `gogem-api` → Source: GitHub `rodrigotjf1-boop/gogem`, branch `main`.
Use **Dockerfile** (recomendado — determinístico). Arquivo `apps/api/Dockerfile` (incluído neste pacote como `Dockerfile.api`): copie-o para o repo em `apps/api/Dockerfile` e no EasyPanel aponte "Dockerfile path" = `apps/api/Dockerfile`, contexto = raiz do repo.

O Dockerfile já roda `prisma generate` e o build; o comando de start executa `prisma migrate deploy` antes do `node dist/main.js` — assim toda subida aplica migrations pendentes.

## 3. Variáveis de ambiente do `gogem-api`

Use o `env.staging.example` deste pacote como base. Resumo:
```
DATABASE_URL=postgresql://gogem:SENHA@gogem-db:5432/gogem?schema=public
REDIS_URL=redis://gogem-redis:6379
JWT_SECRET=<64+ chars aleatórios — gere com: openssl rand -hex 48>
PORT=3000
REGEM_API_BASE=https://api.dmsregem.com/api/v1     # ajuste para o staging do Regem se houver
REGEM_SYNC_TOKEN=<token do equipamento servidor_local — ver §4>
S3_ENDPOINT=http://gogem-media:9000
S3_ACCESS_KEY=...  S3_SECRET_KEY=...  S3_BUCKET=gogem
NODE_ENV=production
```
No EasyPanel os serviços do mesmo projeto se resolvem pelo nome (`gogem-db`, `gogem-redis`, `gogem-media`).

## 4. Lado Regem (bloqueia o import e a venda de volta)

1. Deploy dos PRs **#226** e **#228** no ambiente do Regem que o staging vai consumir;
2. **Aplicar a migration 146** (`comanda.cpf`) na nuvem JUNTO do deploy do #226 — sem ela a venda externa quebra;
3. Cadastrar um **`equipamento` do tipo `servidor_local`** no tenant do cliente piloto no Regem e copiar o `token` → `REGEM_SYNC_TOKEN` do GoGeM. (O tenant do Regem é derivado desse dispositivo — um token por cliente.)

## 5. Subir e validar

Deploy do `gogem-api` no EasyPanel → acompanhar logs: deve aparecer o `migrate deploy` aplicando `init` e o Nest ouvindo na porta 3000.

Rode o **`smoke-test.sh`** deste pacote (ajuste as variáveis do topo):
```bash
bash smoke-test.sh https://api-stg.gogem.com.br
```
Ele executa, em ordem: `GET /health` → `GET /health/db` → `POST /auth/register` (tenant de teste) → `GET /auth/me` → `POST /import/regem` → `GET /produtos` (confere itens com `externalRefs.regem`) → `POST /catalogo/publicar` → `GET /catalogo/publicado` (confere snapshot). Qualquer passo vermelho interrompe com o corpo da resposta.

## 6. Critérios de aceite do deploy
- [ ] `/health` e `/health/db` 200 no domínio público com TLS;
- [ ] Migrations versionadas no repo e aplicadas via `migrate deploy` (zero `db push` em staging);
- [ ] Import do Regem populou o catálogo com `codigo_pdv` no de-para;
- [ ] `POST /catalogo/publicar` gerou a versão 1 e `GET /catalogo/publicado` devolve o snapshot;
- [ ] Backup automático do `gogem-db` configurado no EasyPanel (diário) + teste de restore anotado;
- [ ] Segredos apenas no painel do EasyPanel (nada commitado).

## 7. Armadilhas conhecidas (do repasse técnico)
- Ordem dos PRs: #2→#6; mergear fora de ordem quebra a pilha.
- `GET /catalogo/publicado` ainda é JWT — o smoke usa o JWT do register; o guard por token de dispositivo é a próxima tarefa (pareamento).
- Import é **aditivo** e casa grupos/opções por **nome**: renomeações no Regem duplicam no GoGeM — evitar renomear durante o piloto.
- Login por e-mail: e-mail é único **por tenant**, mas o login busca global — não criar dois tenants com o mesmo e-mail em staging até a decisão ser tomada.
