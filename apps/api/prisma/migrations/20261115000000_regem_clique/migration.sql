-- "Conectar pelo Regem" (Hub DMS, F6, plano "Clique GoGeM -> Regem", 15/11/2026): o presidente da
-- empresa autoriza o totem no proprio Regem e o GoGeM guarda a LIGACAO de cada loja marcada, no
-- lugar do token colado.
--   * integracoes.clique: a ligacao de cada loja (CIFRADA) e a loja em uso. Coluna nova e nula: o
--     codigo de antes a ignora, e NULL = sem clique (vale o token colado de sempre);
--   * regem_clique_pedidos: o pedido em andamento (o resumo do state e o verificador do PKCE
--     cifrado, presos a quem comecou; 10 minutos, uma vez).
-- Idempotente: pode rodar de novo.
ALTER TABLE "integracoes" ADD COLUMN IF NOT EXISTS "clique" JSONB;

CREATE TABLE IF NOT EXISTS "regem_clique_pedidos" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "usuarioId" TEXT NOT NULL,
    "estadoHash" TEXT NOT NULL,
    "verificadorCifrado" TEXT NOT NULL,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "venceEm" TIMESTAMP(3) NOT NULL,
    "usadoEm" TIMESTAMP(3),

    CONSTRAINT "regem_clique_pedidos_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "regem_clique_pedidos_estadoHash_key" ON "regem_clique_pedidos"("estadoHash");

CREATE INDEX IF NOT EXISTS "regem_clique_pedidos_venceEm_idx" ON "regem_clique_pedidos"("venceEm");
