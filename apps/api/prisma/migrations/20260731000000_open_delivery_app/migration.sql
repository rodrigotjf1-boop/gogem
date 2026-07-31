-- App parceiro do modo Open Delivery (GoGeM como provedor da API pública).
CREATE TABLE "open_delivery_apps" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "nome" TEXT NOT NULL,
  "clientId" TEXT NOT NULL,
  "clientSecretHash" TEXT NOT NULL,
  "escopos" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "ativo" BOOLEAN NOT NULL DEFAULT true,
  "ultimoUso" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "open_delivery_apps_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "open_delivery_apps_clientId_key" ON "open_delivery_apps"("clientId");
CREATE INDEX "open_delivery_apps_tenantId_idx" ON "open_delivery_apps"("tenantId");

ALTER TABLE "open_delivery_apps"
  ADD CONSTRAINT "open_delivery_apps_tenantId_fkey"
  FOREIGN KEY ("tenantId") REFERENCES "tenants"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
