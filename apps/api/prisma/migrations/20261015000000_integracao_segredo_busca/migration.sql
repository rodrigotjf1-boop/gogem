-- Segredos das integrações cifrados (pedido do Hub DMS, 15/10/2026): o token do Regem passa a
-- ser guardado cifrado em "config", e a entrada do Regem acha a empresa pelo SHA-256 dele,
-- nesta coluna. A cifra dos valores que já existem é feita pela API ao subir (precisa da chave,
-- que não fica no banco); aqui só a coluna e o índice.
ALTER TABLE "integracoes" ADD COLUMN IF NOT EXISTS "segredoBusca" TEXT;

CREATE INDEX IF NOT EXISTS "integracoes_tipo_segredoBusca_idx" ON "integracoes"("tipo", "segredoBusca");
