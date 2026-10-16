-- Token do totem guardado só como RESUMO (pedido do Hub DMS, 15/10/2026): a coluna "token"
-- passa a ter `sha256:<hex do SHA-256 do token>`; o token em si fica só no totem. A API
-- confere o resumo do X-Device-Token que chega, então os totens já pareados seguem
-- funcionando sem parear de novo. O prefixo impede converter duas vezes.
UPDATE "dispositivos"
SET "token" = 'sha256:' || encode(sha256(convert_to("token", 'UTF8')), 'hex')
WHERE "token" IS NOT NULL AND "token" NOT LIKE 'sha256:%';
