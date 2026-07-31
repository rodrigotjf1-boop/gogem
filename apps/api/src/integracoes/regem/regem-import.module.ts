import { Module } from '@nestjs/common';
import { CardapioModule } from '../../cardapio/cardapio.module';
import { CatalogoModule } from '../../catalogo/catalogo.module';
import { RegemModule } from './regem.module';
import { RegemImportController } from './regem-import.controller';
import { RegemImportService } from './regem-import.service';
import { RegemInboundController } from './regem-inbound.controller';
import { RegemInboundService } from './regem-inbound.service';
import { RegemSyncPoller } from './regem-sync.poller';

/**
 * Módulo da integração Regem (fatia 3): serviço de import + controller
 * `POST /api/v1/import/regem` + sincronização periódica Regem→GoGeM
 * (RegemSyncPoller). O client do catálogo e o resolver de config por tenant vêm
 * do RegemModule; a republicação vem do CatalogoModule.
 */
@Module({
  imports: [RegemModule, CardapioModule, CatalogoModule],
  controllers: [RegemImportController, RegemInboundController],
  providers: [RegemImportService, RegemInboundService, RegemSyncPoller],
  exports: [RegemImportService],
})
export class RegemImportModule {}
