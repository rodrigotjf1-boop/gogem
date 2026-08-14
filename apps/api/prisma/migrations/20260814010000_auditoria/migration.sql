-- Fase 5 (segurança) — trilha de auditoria append-only das ações sensíveis.
CREATE TABLE "auditorias" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "usuarioId" TEXT,
    "papel" TEXT,
    "acao" TEXT NOT NULL,
    "recurso" TEXT,
    "recursoId" TEXT,
    "detalhe" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auditorias_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "auditorias_tenantId_createdAt_idx" ON "auditorias"("tenantId", "createdAt");

ALTER TABLE "auditorias" ADD CONSTRAINT "auditorias_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
