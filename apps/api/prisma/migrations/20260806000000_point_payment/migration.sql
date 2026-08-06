-- Cobrança de cartão na maquininha Point Smart do Mercado Pago (modo PDV).
-- Tenant-scoped. O totem cria a payment intent e faz polling; o MP confirma por
-- webhook. Reusa o access token da integração mercadopago.
CREATE TABLE "point_payments" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "deviceId" TEXT NOT NULL,
  "intentId" TEXT,
  "amountCents" INTEGER NOT NULL,
  "tipo" TEXT NOT NULL DEFAULT 'credit',
  "status" TEXT NOT NULL DEFAULT 'pending',
  "paymentId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "point_payments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "point_payments_tenantId_orderId_key" ON "point_payments"("tenantId", "orderId");
CREATE INDEX "point_payments_tenantId_idx" ON "point_payments"("tenantId");
CREATE INDEX "point_payments_intentId_idx" ON "point_payments"("intentId");

ALTER TABLE "point_payments"
  ADD CONSTRAINT "point_payments_tenantId_fkey"
  FOREIGN KEY ("tenantId") REFERENCES "tenants"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
