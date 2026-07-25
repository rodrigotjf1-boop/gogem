import { Module } from '@nestjs/common';
import { RegemCatalogClient } from './regem-catalog.client';
import { RegemImportController } from './regem-import.controller';
import { RegemImportService } from './regem-import.service';

/**
 * Módulo da integração Regem (fatia 3): cliente do catálogo + serviço de
 * import + controller `POST /api/v1/import/regem`. ConfigService vem do
 * ConfigModule global (app.module).
 *
 * Follow-up documentado: extrair o cliente para `integrations/regem/` como
 * pacote reutilizável; por ora vive em `apps/api`.
 */
@Module({
  controllers: [RegemImportController],
  providers: [RegemCatalogClient, RegemImportService],
  exports: [RegemImportService],
})
export class RegemImportModule {}
