import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RegemModule } from '../integracoes/regem/regem.module';
import { RegemImportModule } from '../integracoes/regem/regem-import.module';
import { IntegracaoController } from './integracao.controller';
import { IntegracaoService } from './integracao.service';

/**
 * IntegracaoModule — área de integrações/conectores (Fase 2).
 *
 * Importa AuthModule (guards), RegemModule (resolver + catalog client para
 * testar) e RegemImportModule (importar catálogo). PrismaService é global.
 */
@Module({
  imports: [AuthModule, RegemModule, RegemImportModule],
  controllers: [IntegracaoController],
  providers: [IntegracaoService],
})
export class IntegracaoModule {}
