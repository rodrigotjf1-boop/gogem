import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DeviceCtx } from '../auth/device-ctx.decorator';
import { DeviceTokenGuard } from '../auth/device-token.guard';
import type { DeviceUser } from '../auth/device-token.guard';
import { RegistrarEventoDto } from './dto/registrar-evento.dto';
import { TelemetriaService } from './telemetria.service';

/**
 * Telemetria — o totem SOBE eventos (erros/avisos) por `X-Device-Token`. O
 * tenant vem do device (contexto). Best-effort no cliente: nunca derruba o app.
 */
@ApiTags('telemetria')
@UseGuards(DeviceTokenGuard)
@Controller('telemetria')
export class TelemetriaDeviceController {
  constructor(private readonly service: TelemetriaService) {}

  @Post('evento')
  @HttpCode(200)
  registrar(@DeviceCtx() ctx: DeviceUser, @Body() dto: RegistrarEventoDto) {
    return this.service.registrar(ctx.deviceId, dto);
  }
}
