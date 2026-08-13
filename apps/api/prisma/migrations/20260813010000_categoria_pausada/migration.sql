-- Pausar categoria inteira (some do cardápio do totem sem excluir).
-- Tabela real = "categorias" (model Categoria tem @@map("categorias")).
ALTER TABLE "categorias" ADD COLUMN "pausada" BOOLEAN NOT NULL DEFAULT false;
