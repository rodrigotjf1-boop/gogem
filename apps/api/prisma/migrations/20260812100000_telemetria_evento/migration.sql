-- Eventos de telemetria dos totens (erro/aviso/info). O totem sobe; o Console
-- da Distribuição lê cross-tenant.
CREATE TABLE "telemetria_eventos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "dispositivoId" TEXT NOT NULL,
    "nivel" TEXT NOT NULL DEFAULT 'erro',
    "mensagem" TEXT NOT NULL,
    "detalhe" TEXT,
    "appVersao" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "telemetria_eventos_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "telemetria_eventos_tenantId_idx" ON "telemetria_eventos"("tenantId");
CREATE INDEX "telemetria_eventos_createdAt_idx" ON "telemetria_eventos"("createdAt");
