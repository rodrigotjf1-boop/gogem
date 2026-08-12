-- Arte da categoria (roleta do totem GoGen/brasa): imagem, emoji e cor.
-- Todos opcionais e aditivos — sem impacto em dados existentes.
ALTER TABLE "Categoria" ADD COLUMN "imagemUrl" TEXT;
ALTER TABLE "Categoria" ADD COLUMN "emoji" TEXT;
ALTER TABLE "Categoria" ADD COLUMN "cor" TEXT;
