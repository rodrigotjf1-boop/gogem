-- Pedidos e eventos do modo Open Delivery (GoGeM provedor).
CREATE TABLE "open_delivery_orders" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "appId" TEXT,
  "displayId" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PLACED',
  "customerNome" TEXT,
  "customerDoc" TEXT,
  "itens" JSONB NOT NULL,
  "pagamentos" JSONB NOT NULL,
  "totalCentavos" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "open_delivery_orders_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "open_delivery_orders_tenantId_displayId_key"
  ON "open_delivery_orders"("tenantId", "displayId");
CREATE INDEX "open_delivery_orders_tenantId_idx" ON "open_delivery_orders"("tenantId");
ALTER TABLE "open_delivery_orders"
  ADD CONSTRAINT "open_delivery_orders_tenantId_fkey"
  FOREIGN KEY ("tenantId") REFERENCES "tenants"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "open_delivery_events" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "tipo" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "acknowledgedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "open_delivery_events_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "open_delivery_events_tenantId_acknowledgedAt_idx"
  ON "open_delivery_events"("tenantId", "acknowledgedAt");
ALTER TABLE "open_delivery_events"
  ADD CONSTRAINT "open_delivery_events_tenantId_fkey"
  FOREIGN KEY ("tenantId") REFERENCES "tenants"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
