import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { DeviceCtx } from '../auth/device-ctx.decorator';
import { DeviceTokenGuard } from '../auth/device-token.guard';
import type { DeviceUser } from '../auth/device-token.guard';
import { DispositivoService } from './dispositivo.service';
import { HeartbeatDto } from './dto/heartbeat.dto';

/**
 * Telemetria do totem — device-authed (X-Device-Token). O totem manda um
 * heartbeat periódico com o estado atual (papel, fila, versão); o admin (Frota)
 * deriva online/offline pela recência. Rota separada da administrativa (que é
 * JWT+gerente) porque o autenticador aqui é o token de dispositivo.
 */
@ApiTags('dispositivos')
@UseGuards(DeviceTokenGuard)
@Controller('dispositivos')
export class DispositivoDeviceController {
  constructor(private readonly dispositivos: DispositivoService) {}

  @Post('heartbeat')
  @ApiOkResponse({
    description: 'Registra o heartbeat + estado do dispositivo.',
  })
  heartbeat(@DeviceCtx() ctx: DeviceUser, @Body() dto: HeartbeatDto) {
    return this.dispositivos.heartbeat(ctx.deviceId, dto);
  }
}
