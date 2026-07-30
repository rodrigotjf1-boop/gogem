-- Selo de destaque do produto (F4 do épico "Totem moderno"): texto curto exibido
-- no card do totem (ex.: "Mais vendido", "Novidade", "Chef"). Nulo = sem selo.
ALTER TABLE "produtos" ADD COLUMN "selo" TEXT;
