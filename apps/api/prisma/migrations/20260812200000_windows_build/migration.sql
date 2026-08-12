-- Build do totem para Windows (só download; não há auto-update no Windows).
CREATE TABLE "windows_builds" (
    "id" TEXT NOT NULL,
    "versao" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "sha256" TEXT NOT NULL,
    "notas" TEXT,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "windows_builds_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "windows_builds_versao_key" ON "windows_builds"("versao");
