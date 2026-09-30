-- Estilo do totem (decisão do dono, 30/09/2026): o "Padrão GoGeM" saiu da lista do painel.
-- Loja nova começa no Brasa (steakhouse); quem estava no Padrão passa para o GoGen, que o
-- app dos totens (0.5.25) já desenha. O Burger House migra depois, para o Brasa 2.0, só
-- quando o APK que conhece o Brasa 2.0 estiver nos totens.
ALTER TABLE "aparencias" ALTER COLUMN "temaPreset" SET DEFAULT 'brasa';
UPDATE "aparencias" SET "temaPreset" = 'gogen' WHERE "temaPreset" = 'padrao';
