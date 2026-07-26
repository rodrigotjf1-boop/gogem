import { Module } from '@nestjs/common';
import { DispositivoController } from './dispositivo.controller';
import { DispositivoPublicoController } from './dispositivo-publico.controller';
import { DispositivoService } from './dispositivo.service';

/**
 * DispositivoModule — admin de totens (JWT + gerente) + pareamento público
 * (issue #12.1). O PrismaService vem do PrismaModule global.
 */
@Module({
  controllers: [DispositivoController, DispositivoPublicoController],
  providers: [DispositivoService],
  exports: [DispositivoService],
})
export class DispositivoModule {}
