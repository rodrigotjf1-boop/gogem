-- Avisos assinados do Regem ao GoGeM (contrato 1 dos AVISOS-ASSINADOS, fase 3 da credencial
-- própria do GoGeM, 20/10/2026): o segredo `whsec_` que o GoGeM gera e registra no Regem
-- (cifrado), o anterior durante a troca e o estado do registro. Coluna nova e nula: o código de
-- antes a ignora, e NULL = avisos não ligados (o Regem segue pelo caminho antigo).
ALTER TABLE "integracoes" ADD COLUMN IF NOT EXISTS "avisos" JSONB;
