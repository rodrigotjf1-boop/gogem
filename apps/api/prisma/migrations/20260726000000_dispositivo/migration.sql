-- CreateTable
CREATE TABLE "dispositivos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "unidadeId" TEXT,
    "nome" TEXT NOT NULL,
    "tipo" TEXT NOT NULL DEFAULT 'totem',
    "token" TEXT,
    "pareado" BOOLEAN NOT NULL DEFAULT false,
    "codigoPareamento" TEXT,
    "codigoExpiraEm" TIMESTAMP(3),
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dispositivos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "dispositivos_token_key" ON "dispositivos"("token");

-- CreateIndex
CREATE INDEX "dispositivos_tenantId_idx" ON "dispositivos"("tenantId");

-- AddForeignKey
ALTER TABLE "dispositivos" ADD CONSTRAINT "dispositivos_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

