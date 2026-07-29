-- CreateTable
CREATE TABLE "aparencias" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "corPrimaria" TEXT NOT NULL DEFAULT '#FFC24B',
    "corDestaque" TEXT NOT NULL DEFAULT '#3ECF8E',
    "corFundo" TEXT NOT NULL DEFAULT '#0F1713',
    "corPainel" TEXT NOT NULL DEFAULT '#16211B',
    "raio" INTEGER NOT NULL DEFAULT 16,
    "nomeLoja" TEXT,
    "logoUrl" TEXT,
    "fonteDisplay" TEXT NOT NULL DEFAULT 'Tektur',
    "descansoTipo" TEXT NOT NULL DEFAULT 'padrao',
    "descansoIntervaloSeg" INTEGER NOT NULL DEFAULT 6,
    "descansoMidias" JSONB NOT NULL DEFAULT '[]',
    "chamada" TEXT NOT NULL DEFAULT 'TOQUE PARA PEDIR',
    "precoIsca" TEXT,
    "estiloCard" TEXT NOT NULL DEFAULT 'cheia',
    "animacoes" TEXT NOT NULL DEFAULT 'cheio',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "aparencias_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "aparencias_tenantId_key" ON "aparencias"("tenantId");

-- AddForeignKey
ALTER TABLE "aparencias" ADD CONSTRAINT "aparencias_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
