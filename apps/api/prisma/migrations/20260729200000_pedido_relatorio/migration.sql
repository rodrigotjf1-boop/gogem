-- Campos de relatório no Pedido (Fase 7): nome do cliente, total (centavos),
-- e cancelamento. Índices para consultas por período/status.
ALTER TABLE "pedidos" ADD COLUMN "cliente" TEXT;
ALTER TABLE "pedidos" ADD COLUMN "totalCentavos" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "pedidos" ADD COLUMN "canceladoEm" TIMESTAMP(3);
ALTER TABLE "pedidos" ADD COLUMN "canceladoMotivo" TEXT;

-- Backfill do total dos pedidos já existentes: soma de pagamentos[].valor.
UPDATE "pedidos" p
SET "totalCentavos" = COALESCE((
  SELECT SUM((e->>'valor')::int)
  FROM jsonb_array_elements(p."pagamentos") AS e
  WHERE e ? 'valor'
), 0)
WHERE jsonb_typeof(p."pagamentos") = 'array';

-- CreateIndex
CREATE INDEX "pedidos_tenantId_status_idx" ON "pedidos"("tenantId", "status");
CREATE INDEX "pedidos_tenantId_createdAt_idx" ON "pedidos"("tenantId", "createdAt");
