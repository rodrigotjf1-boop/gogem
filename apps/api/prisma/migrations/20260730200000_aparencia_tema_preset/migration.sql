-- Preset de tema do totem (F3 do épico "Totem moderno"): 'padrao' | 'brasa'.
-- Default 'padrao' (retrocompat). As legendas por slide do descanso
-- (kicker/titulo/subtitulo) vivem dentro do Json `descansoMidias` — sem coluna.
ALTER TABLE "aparencias" ADD COLUMN "temaPreset" TEXT NOT NULL DEFAULT 'padrao';
