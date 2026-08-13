-- F3 do espelho — fila de conflitos (loja é a fonte da verdade e o Regem diverge).
CREATE TABLE "catalogo_conflitos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "produtoId" TEXT NOT NULL,
    "codigo" TEXT NOT NULL,
    "campo" TEXT NOT NULL,
    "valorRegem" TEXT NOT NULL,
    "valorGogem" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'aberto',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "catalogo_conflitos_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "catalogo_conflitos_tenantId_produtoId_campo_key"
    ON "catalogo_conflitos"("tenantId", "produtoId", "campo");
CREATE INDEX "catalogo_conflitos_tenantId_idx" ON "catalogo_conflitos"("tenantId");

ALTER TABLE "catalogo_conflitos" ADD CONSTRAINT "catalogo_conflitos_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
