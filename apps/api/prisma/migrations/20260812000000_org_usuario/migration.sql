-- Usuário da organização (DMS) — Console da Distribuição. Cross-tenant (sem
-- tenantId), e-mail único global, auth própria.
CREATE TABLE "org_usuarios" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "senhaHash" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "papel" TEXT NOT NULL DEFAULT 'admin',
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "org_usuarios_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "org_usuarios_email_key" ON "org_usuarios"("email");
