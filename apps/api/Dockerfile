# apps/api/Dockerfile — build da API GoGeM no monorepo pnpm.
# Contexto de build = RAIZ do repo. No EasyPanel: "Dockerfile path" = apps/api/Dockerfile.
FROM node:20-alpine AS base
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

FROM node:20-alpine AS runner
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
