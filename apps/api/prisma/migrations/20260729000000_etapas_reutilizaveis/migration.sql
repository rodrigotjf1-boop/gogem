-- Etapas reutilizáveis: ComplementoGrupo deixa de ser preso a um produto; o
-- vínculo produto↔etapa vai para produto_complementos (N:N, com ordem por
-- produto). Preserva os dados: cada grupo atual vira uma etapa reutilizável já
-- vinculada ao seu produto.

-- CreateTable (vínculo)
CREATE TABLE "produto_complementos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "produtoId" TEXT NOT NULL,
    "grupoId" TEXT NOT NULL,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produto_complementos_pkey" PRIMARY KEY ("id")
);

-- Backfill: um vínculo por grupo existente (produtoId + ordem atuais).
INSERT INTO "produto_complementos" ("id", "tenantId", "produtoId", "grupoId", "ordem", "createdAt", "updatedAt")
SELECT gen_random_uuid(), "tenantId", "produtoId", "id", "ordem", now(), now()
FROM "complemento_grupos";

-- CreateIndex
CREATE UNIQUE INDEX "produto_complementos_produtoId_grupoId_key" ON "produto_complementos"("produtoId", "grupoId");
CREATE INDEX "produto_complementos_tenantId_idx" ON "produto_complementos"("tenantId");
CREATE INDEX "produto_complementos_produtoId_idx" ON "produto_complementos"("produtoId");
CREATE INDEX "produto_complementos_grupoId_idx" ON "produto_complementos"("grupoId");

-- AddForeignKey
ALTER TABLE "produto_complementos" ADD CONSTRAINT "produto_complementos_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "produto_complementos" ADD CONSTRAINT "produto_complementos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "produto_complementos" ADD CONSTRAINT "produto_complementos_grupoId_fkey" FOREIGN KEY ("grupoId") REFERENCES "complemento_grupos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ComplementoGrupo vira reutilizável: some produtoId + ordem.
ALTER TABLE "complemento_grupos" DROP CONSTRAINT IF EXISTS "complemento_grupos_produtoId_fkey";
DROP INDEX IF EXISTS "complemento_grupos_produtoId_idx";
ALTER TABLE "complemento_grupos" DROP COLUMN "produtoId";
ALTER TABLE "complemento_grupos" DROP COLUMN "ordem";

-- Foto na opção.
ALTER TABLE "complemento_opcoes" ADD COLUMN "imagemUrl" TEXT;
