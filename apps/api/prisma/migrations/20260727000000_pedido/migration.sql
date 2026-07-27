-- CreateTable
CREATE TABLE "pedidos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "dispositivoId" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "cpf" TEXT,
    "itens" JSONB NOT NULL,
    "pagamentos" JSONB NOT NULL,
    "taxaServicoPct" INTEGER,
    "senhaLocal" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'pendente',
    "regemComandaId" TEXT,
    "regemSenha" INTEGER,
    "regemResposta" JSONB,
    "erro" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pedidos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "pedidos_tenantId_idx" ON "pedidos"("tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "pedidos_tenantId_idempotencyKey_key" ON "pedidos"("tenantId", "idempotencyKey");

-- AddForeignKey
ALTER TABLE "pedidos" ADD CONSTRAINT "pedidos_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

