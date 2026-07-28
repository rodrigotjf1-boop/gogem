# Admin (retaguarda) — build estático (Vite) servido por nginx.
# Contexto de build = RAIZ do monorepo (por causa do pnpm workspace).
#   docker build -f apps/admin/Dockerfile --build-arg VITE_API_URL=https://api.gogem.com.br/api/v1 .
#
# ATENÇÃO: o Vite bakeia VITE_API_URL em BUILD-TIME. Para trocar a URL da API,
# rebuild a imagem com o novo --build-arg.

FROM node:20-alpine AS build
WORKDIR /repo
RUN corepack enable
# Manifestos primeiro (cache de deps)
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
COPY apps/admin/package.json apps/admin/package.json
RUN pnpm install --frozen-lockfile=false
# Código + build
COPY apps/admin apps/admin
ARG VITE_API_URL=https://api.gogem.com.br/api/v1
ENV VITE_API_URL=$VITE_API_URL
RUN pnpm -F @gogem/admin run build

FROM nginx:1.27-alpine
COPY apps/admin/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/apps/admin/dist /usr/share/nginx/html
EXPOSE 80
