-- Endereço do servidor da loja para ESTE totem (G1).
--
-- Até aqui o host vivia dentro do APK (`--dart-define=GOGEM_API_URL`), então trocar o
-- destino de um aparelho exigia gerar e instalar um APK novo. Com a coluna, o pareamento
-- entrega o endereço e o MESMO aplicativo serve loja com servidor local e loja sem ele.
--
-- NULL = nuvem (comportamento de hoje, e o padrão de quem não usa servidor local).
-- Preenchido = o totem fala com o servidor da loja naquele endereço.
-- Nome real da tabela ("dispositivos", por causa do @@map) — o Prisma não traduz SQL cru.
ALTER TABLE "dispositivos" ADD COLUMN IF NOT EXISTS "apiBase" TEXT;
