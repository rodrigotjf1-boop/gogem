-- Release do APK do totem (auto-update). GLOBAL (sem tenantId — o app é o mesmo
-- produto para todas as lojas). O DMS publica; o totem consulta /kiosk/latest.
CREATE TABLE "kiosk_releases" (
  "id" TEXT NOT NULL,
  "versionCode" INTEGER NOT NULL,
  "versionName" TEXT NOT NULL,
  "apkUrl" TEXT NOT NULL,
  "sha256" TEXT NOT NULL,
  "notas" TEXT,
  "obrigatorio" BOOLEAN NOT NULL DEFAULT false,
  "ativo" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "kiosk_releases_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "kiosk_releases_versionCode_key" ON "kiosk_releases"("versionCode");
