-- Arte da categoria (roleta do totem GoGen/brasa): imagem, emoji e cor.
-- Todos opcionais e aditivos — sem impacto em dados existentes.
-- Tabela real = "categorias" (model Categoria tem @@map("categorias")).
ALTER TABLE "categorias" ADD COLUMN "imagemUrl" TEXT;
ALTER TABLE "categorias" ADD COLUMN "emoji" TEXT;
ALTER TABLE "categorias" ADD COLUMN "cor" TEXT;
