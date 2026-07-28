-- CreateTable
CREATE TABLE "integracoes" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "tipo" TEXT NOT NULL,
    "nome" TEXT,
    "ativo" BOOLEAN NOT NULL DEFAULT false,
    "config" JSONB NOT NULL DEFAULT '{}',
    "ultimoTeste" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "integracoes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "integracoes_tenantId_idx" ON "integracoes"("tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "integracoes_tenantId_tipo_key" ON "integracoes"("tenantId", "tipo");

-- AddForeignKey
ALTER TABLE "integracoes" ADD CONSTRAINT "integracoes_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
