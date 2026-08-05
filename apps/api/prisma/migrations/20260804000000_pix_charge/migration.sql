-- Cobrança PIX via PSP (F8). Tenant-scoped. O totem cria e faz polling; o PSP
-- confirma por webhook. Credenciais do PSP ficam no backend.
CREATE TABLE "pix_charges" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "amountCents" INTEGER NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "psp" TEXT NOT NULL,
  "pspRef" TEXT,
  "copiaECola" TEXT,
  "qrImage" TEXT,
  "expiresAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "pix_charges_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "pix_charges_tenantId_orderId_key" ON "pix_charges"("tenantId", "orderId");
CREATE INDEX "pix_charges_tenantId_idx" ON "pix_charges"("tenantId");
CREATE INDEX "pix_charges_pspRef_idx" ON "pix_charges"("pspRef");

ALTER TABLE "pix_charges"
  ADD CONSTRAINT "pix_charges_tenantId_fkey"
  FOREIGN KEY ("tenantId") REFERENCES "tenants"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
