import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AparenciaController } from './aparencia.controller';
import { AparenciaService } from './aparencia.service';

/**
 * AparenciaModule — aparência do totem por loja (Fase 6). Exporta o
 * AparenciaService para o CatalogoModule embutir a aparência no
 * `/catalogo/publicado`. PrismaService é global.
 */
@Module({
  imports: [AuthModule],
  controllers: [AparenciaController],
  providers: [AparenciaService],
  exports: [AparenciaService],
})
export class AparenciaModule {}
