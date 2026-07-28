# apps/api/Dockerfile — build da API GoGeM no monorepo pnpm.
# Contexto de build = RAIZ do repo. No EasyPanel: "Dockerfile path" = apps/api/Dockerfile.
#
# Base Debian (slim), NÃO Alpine: no Alpine o Prisma não detecta a libssl e o
# schema/migration engine quebra ("Could not parse schema engine response").
# Debian tem OpenSSL 3.0 e o Prisma funciona out-of-the-box (+ openssl explícito).
FROM node:20-slim AS base
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN corepack enable && corepack prepare pnpm@9 --activate
WORKDIR /app

# Build. Copiamos o repo inteiro ANTES do install (o .dockerignore exclui
# node_modules/dist/.git) para que o --frozen-lockfile valide contra TODOS os
# manifests do workspace — não quebra quando o workspace cresce (ex.: o admin
# entra na main). Troca cache de layer por robustez; aceitável para staging.
FROM base AS build
COPY . .
RUN pnpm install --frozen-lockfile --filter @gogem/api... \
 && pnpm -F @gogem/api exec prisma generate \
 && pnpm -F @gogem/api run build \
 && pnpm prune --prod

FROM node:20-slim AS runner
# openssl também no runtime: o `prisma migrate deploy` do CMD roda aqui.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=build /app/apps/api/dist ./apps/api/dist
COPY --from=build /app/apps/api/prisma ./apps/api/prisma
COPY --from=build /app/apps/api/package.json ./apps/api/
WORKDIR /app/apps/api
EXPOSE 3000
# Aplica migrations pendentes a cada subida, depois inicia.
# `prisma` (CLI) é DEPENDENCY (não devDep) → sobrevive ao `prune --prod` e está
# disponível aqui em runtime para o `migrate deploy`.
CMD npx prisma migrate deploy && node dist/main.js
