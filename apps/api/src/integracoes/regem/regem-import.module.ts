import { Module } from '@nestjs/common';
import { RegemModule } from './regem.module';
import { RegemImportController } from './regem-import.controller';
import { RegemImportService } from './regem-import.service';

/**
 * Módulo da integração Regem (fatia 3): serviço de import + controller
 * `POST /api/v1/import/regem`. O client do catálogo e o resolver de config por
 * tenant vêm do RegemModule.
 */
@Module({
  imports: [RegemModule],
  controllers: [RegemImportController],
  providers: [RegemImportService],
  exports: [RegemImportService],
})
export class RegemImportModule {}
