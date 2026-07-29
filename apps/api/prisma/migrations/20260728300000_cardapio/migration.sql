-- CreateTable
CREATE TABLE "cardapios" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "ativo" BOOLEAN NOT NULL DEFAULT false,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cardapios_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "cardapios_tenantId_idx" ON "cardapios"("tenantId");

-- AddForeignKey
ALTER TABLE "cardapios" ADD CONSTRAINT "cardapios_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AlterTable: cardapioId (nullable) em categorias e produtos
ALTER TABLE "categorias" ADD COLUMN "cardapioId" TEXT;
ALTER TABLE "produtos" ADD COLUMN "cardapioId" TEXT;

-- CreateIndex
CREATE INDEX "categorias_cardapioId_idx" ON "categorias"("cardapioId");
CREATE INDEX "produtos_cardapioId_idx" ON "produtos"("cardapioId");

-- Backfill: cria um "Cardápio padrão" ATIVO por tenant e vincula o catálogo
-- existente a ele (nada quebra; o totem continua recebendo o mesmo conteúdo).
INSERT INTO "cardapios" ("id", "tenantId", "nome", "ativo", "ordem", "createdAt", "updatedAt")
SELECT gen_random_uuid(), t."id", 'Cardápio padrão', true, 0, now(), now()
FROM "tenants" t;

UPDATE "categorias" c
SET "cardapioId" = ca."id"
FROM "cardapios" ca
WHERE ca."tenantId" = c."tenantId" AND c."cardapioId" IS NULL;

UPDATE "produtos" p
SET "cardapioId" = ca."id"
FROM "cardapios" ca
WHERE ca."tenantId" = p."tenantId" AND p."cardapioId" IS NULL;

-- AddForeignKey
ALTER TABLE "categorias" ADD CONSTRAINT "categorias_cardapioId_fkey" FOREIGN KEY ("cardapioId") REFERENCES "cardapios"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "produtos" ADD CONSTRAINT "produtos_cardapioId_fkey" FOREIGN KEY ("cardapioId") REFERENCES "cardapios"("id") ON DELETE SET NULL ON UPDATE CASCADE;
