-- F10 — journal append-only das transações Point (auditoria/reconciliação).
CREATE TABLE "point_journal" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "pointPaymentId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "intentId" TEXT,
    "amountCents" INTEGER NOT NULL,
    "tipo" TEXT,
    "bandeira" TEXT,
    "status" TEXT NOT NULL,
    "paymentId" TEXT,
    "origem" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "point_journal_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "point_journal_tenantId_idx" ON "point_journal"("tenantId");
CREATE INDEX "point_journal_pointPaymentId_idx" ON "point_journal"("pointPaymentId");
CREATE INDEX "point_journal_orderId_idx" ON "point_journal"("orderId");

ALTER TABLE "point_journal" ADD CONSTRAINT "point_journal_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
