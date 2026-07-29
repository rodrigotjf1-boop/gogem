import { Module } from '@nestjs/common';
import { RegemConfigResolver } from './regem-config.resolver';
import { RegemCatalogClient } from './regem-catalog.client';
import { RegemSalesClient } from './regem-sales.client';
import { RegemPauseClient } from './regem-pause.client';

/**
 * RegemModule — peças compartilhadas do conector Regem: o resolver de config
 * por tenant e os dois clients HTTP (catálogo + venda). Quem precisa de um
 * client importa este módulo (RegemImportModule, VendasModule, IntegracaoModule)
 * em vez de re-declarar o provider. PrismaService/ConfigService vêm dos módulos
 * globais.
 */
@Module({
  providers: [
    RegemConfigResolver,
    RegemCatalogClient,
    RegemSalesClient,
    RegemPauseClient,
  ],
  exports: [
    RegemConfigResolver,
    RegemCatalogClient,
    RegemSalesClient,
    RegemPauseClient,
  ],
})
export class RegemModule {}
