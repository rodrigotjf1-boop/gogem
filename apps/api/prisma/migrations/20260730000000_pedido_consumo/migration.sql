-- Tipo de consumo do pedido (F1 do épico "Totem moderno"): 'local' (comer aqui)
-- ou 'viagem' (para viagem). Default 'local' para retrocompatibilidade.
ALTER TABLE "pedidos" ADD COLUMN "consumo" TEXT NOT NULL DEFAULT 'local';
