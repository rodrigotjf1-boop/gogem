-- Certificado da autoridade do servidor da loja, entregue ao totem no pareamento (K2).
--
-- O servidor local serve HTTPS com um certificado próprio, gerado POR INSTALAÇÃO
-- (edge/gen-cert.mjs). O Android não confia nele, e o cliente HTTP do totem recusaria a
-- conexão. Guardando a CA aqui, o pareamento a entrega junto com o endereço — sem isso
-- seria preciso gerar um APK por loja só para embutir o certificado.
--
-- É certificado PÚBLICO (a parte que se distribui), nunca a chave privada.
-- Nome real da tabela ("dispositivos", por causa do @@map).
ALTER TABLE "dispositivos" ADD COLUMN IF NOT EXISTS "caPem" TEXT;
