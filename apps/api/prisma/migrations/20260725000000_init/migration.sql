-- CreateEnum
CREATE TYPE "Papel" AS ENUM ('presidente', 'gerente', 'supervisao', 'execucao');

-- CreateTable
CREATE TABLE "tenants" (
    "id" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tenants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "unidades" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "unidades_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "usuarios" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "unidadeId" TEXT,
    "nome" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "senhaHash" TEXT NOT NULL,
    "papel" "Papel" NOT NULL DEFAULT 'execucao',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categorias" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categorias_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produtos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "categoriaId" TEXT,
    "nome" TEXT NOT NULL,
    "descricao" TEXT,
    "precoCentavos" INTEGER NOT NULL DEFAULT 0,
    "disponivel" BOOLEAN NOT NULL DEFAULT true,
    "externalRefs" JSONB NOT NULL DEFAULT '[]',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produtos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "complemento_grupos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "produtoId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "min" INTEGER NOT NULL DEFAULT 0,
    "max" INTEGER,
    "obrigatorio" BOOLEAN NOT NULL DEFAULT false,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "complemento_grupos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "complemento_opcoes" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "grupoId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "precoCentavosDelta" INTEGER NOT NULL DEFAULT 0,
    "disponivel" BOOLEAN NOT NULL DEFAULT true,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "externalRefs" JSONB NOT NULL DEFAULT '[]',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "complemento_opcoes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_versions" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "versao" INTEGER NOT NULL,
    "snapshot" JSONB NOT NULL,
    "publishedById" TEXT,
    "publishedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "menu_versions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "unidades_tenantId_idx" ON "unidades"("tenantId");

-- CreateIndex
CREATE INDEX "usuarios_tenantId_idx" ON "usuarios"("tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "usuarios_tenantId_email_key" ON "usuarios"("tenantId", "email");

-- CreateIndex
CREATE INDEX "categorias_tenantId_idx" ON "categorias"("tenantId");

-- CreateIndex
CREATE INDEX "produtos_tenantId_idx" ON "produtos"("tenantId");

-- CreateIndex
CREATE INDEX "produtos_categoriaId_idx" ON "produtos"("categoriaId");

-- CreateIndex
CREATE INDEX "complemento_grupos_tenantId_idx" ON "complemento_grupos"("tenantId");

-- CreateIndex
CREATE INDEX "complemento_grupos_produtoId_idx" ON "complemento_grupos"("produtoId");

-- CreateIndex
CREATE INDEX "complemento_opcoes_tenantId_idx" ON "complemento_opcoes"("tenantId");

-- CreateIndex
CREATE INDEX "complemento_opcoes_grupoId_idx" ON "complemento_opcoes"("grupoId");

-- CreateIndex
CREATE INDEX "menu_versions_tenantId_idx" ON "menu_versions"("tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "menu_versions_tenantId_versao_key" ON "menu_versions"("tenantId", "versao");

-- AddForeignKey
ALTER TABLE "unidades" ADD CONSTRAINT "unidades_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "usuarios" ADD CONSTRAINT "usuarios_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "usuarios" ADD CONSTRAINT "usuarios_unidadeId_fkey" FOREIGN KEY ("unidadeId") REFERENCES "unidades"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categorias" ADD CONSTRAINT "categorias_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos" ADD CONSTRAINT "produtos_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos" ADD CONSTRAINT "produtos_categoriaId_fkey" FOREIGN KEY ("categoriaId") REFERENCES "categorias"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complemento_grupos" ADD CONSTRAINT "complemento_grupos_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complemento_grupos" ADD CONSTRAINT "complemento_grupos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complemento_opcoes" ADD CONSTRAINT "complemento_opcoes_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complemento_opcoes" ADD CONSTRAINT "complemento_opcoes_grupoId_fkey" FOREIGN KEY ("grupoId") REFERENCES "complemento_grupos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_versions" ADD CONSTRAINT "menu_versions_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

