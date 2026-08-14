-- Integração por loja (Unidade): token dedicado por loja, desacoplado do edge.
-- unidadeId NULL = config no nível da empresa (piloto / fallback).
ALTER TABLE "integracoes" ADD COLUMN "unidadeId" TEXT;

-- Troca a unicidade (tenant,tipo) → (tenant,unidade,tipo).
DROP INDEX "integracoes_tenantId_tipo_key";
CREATE UNIQUE INDEX "integracoes_tenantId_unidadeId_tipo_key"
    ON "integracoes"("tenantId", "unidadeId", "tipo");
CREATE INDEX "integracoes_unidadeId_idx" ON "integracoes"("unidadeId");

ALTER TABLE "integracoes" ADD CONSTRAINT "integracoes_unidadeId_fkey"
    FOREIGN KEY ("unidadeId") REFERENCES "unidades"("id") ON DELETE SET NULL ON UPDATE CASCADE;
