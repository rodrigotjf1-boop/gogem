# Admin (retaguarda) — build estático (Vite) servido por nginx.
# Contexto de build = RAIZ do monorepo (por causa do pnpm workspace).
#   docker build -f apps/admin/Dockerfile --build-arg VITE_API_URL=https://api.gogem.com.br/api/v1 .
#
# ATENÇÃO: o Vite bakeia VITE_API_URL em BUILD-TIME. Para trocar a URL da API,
# rebuild a imagem com o novo --build-arg.

FROM node:20-alpine AS build
RUN corepack enable && corepack prepare pnpm@9 --activate
WORKDIR /repo
# Repo inteiro ANTES do install (o .dockerignore da RAIZ exclui node_modules/
# dist/.git/apps/kiosk) → o --frozen-lockfile valida contra TODOS os manifests
# do workspace. Robusto quando o monorepo cresce (espelha o Dockerfile da API).
COPY . .
ARG VITE_API_URL=https://api.gogem.com.br/api/v1
ENV VITE_API_URL=$VITE_API_URL
RUN pnpm install --frozen-lockfile --filter @gogem/admin... \
 && pnpm -F @gogem/admin run build

FROM nginx:1.27-alpine
COPY apps/admin/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/apps/admin/dist /usr/share/nginx/html
EXPOSE 80
