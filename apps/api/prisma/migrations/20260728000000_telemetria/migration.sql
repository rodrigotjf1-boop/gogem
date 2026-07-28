-- Telemetria da frota: heartbeat + último estado reportado pelo dispositivo.
-- AlterTable
ALTER TABLE "dispositivos"
  ADD COLUMN "ultimoHeartbeat" TIMESTAMP(3),
  ADD COLUMN "ultimoStatus" JSONB;
