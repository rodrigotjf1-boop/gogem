-- Maquininha Point vinculada a cada totem (modo PDV, multi-terminal). Nulo = usa
-- o device_id padrão da loja (integração Mercado Pago).
ALTER TABLE "dispositivos" ADD COLUMN "pointDeviceId" TEXT;
