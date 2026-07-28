import { Module } from '@nestjs/common';
import { DispositivoController } from './dispositivo.controller';
import { DispositivoDeviceController } from './dispositivo-device.controller';
import { DispositivoPublicoController } from './dispositivo-publico.controller';
import { DispositivoService } from './dispositivo.service';

/**
 * DispositivoModule — admin de totens (JWT + gerente) + pareamento público
 * (issue #12.1) + telemetria/heartbeat (device-authed). O PrismaService vem do
 * PrismaModule global.
 */
@Module({
  controllers: [
    DispositivoController,
    DispositivoDeviceController,
    DispositivoPublicoController,
  ],
  providers: [DispositivoService],
  exports: [DispositivoService],
})
export class DispositivoModule {}
