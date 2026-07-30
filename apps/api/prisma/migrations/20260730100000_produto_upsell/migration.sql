-- Upsell "Peça também" (F2 do épico "Totem moderno"): sugestões por produto,
-- configuradas no admin. Auto-referência N:N em produtos.
CREATE TABLE "produto_upsells" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "produtoId" TEXT NOT NULL,
  "sugeridoId" TEXT NOT NULL,
  "ordem" INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT "produto_upsells_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "produto_upsells_produtoId_sugeridoId_key"
  ON "produto_upsells"("produtoId", "sugeridoId");
CREATE INDEX "produto_upsells_tenantId_idx" ON "produto_upsells"("tenantId");
CREATE INDEX "produto_upsells_produtoId_idx" ON "produto_upsells"("produtoId");

ALTER TABLE "produto_upsells"
  ADD CONSTRAINT "produto_upsells_tenantId_fkey"
  FOREIGN KEY ("tenantId") REFERENCES "tenants"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "produto_upsells"
  ADD CONSTRAINT "produto_upsells_produtoId_fkey"
  FOREIGN KEY ("produtoId") REFERENCES "produtos"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "produto_upsells"
  ADD CONSTRAINT "produto_upsells_sugeridoId_fkey"
  FOREIGN KEY ("sugeridoId") REFERENCES "produtos"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
