import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DeviceTokenGuard } from '../auth/device-token.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CriarPointDto } from './dto/criar-point.dto';
import { PointService } from './point.service';

/**
 * Cartão na maquininha Point Smart (modo PDV). O totem cria a intent (a
 * maquininha acende) e faz polling do status; o MP confirma por webhook. Tenant
 * pelo X-Device-Token; webhook público (casa por intentId).
 */
@ApiTags('pagamentos')
@Controller('pagamentos/point')
export class PointController {
  constructor(private readonly service: PointService) {}

  // Admin (JWT): lista as maquininhas Point da conta p/ escolher o device_id.
  // ANTES de `:id` para não ser capturado pela rota de status.
  @Get('devices')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('gerente')
  listarDevices() {
    return this.service.listarDevices();
  }

  @Post()
  @UseGuards(DeviceTokenGuard)
  criar(@Body() dto: CriarPointDto) {
    return this.service.criar(dto);
  }

  @Get(':id')
  @UseGuards(DeviceTokenGuard)
  status(@Param('id') id: string) {
    return this.service.status(id);
  }

  @Post(':id/cancelar')
  @UseGuards(DeviceTokenGuard)
  @HttpCode(200)
  cancelar(@Param('id') id: string) {
    return this.service.cancelar(id);
  }

  @Post('webhook')
  @HttpCode(200)
  webhook(@Body() body: unknown, @Query() query: Record<string, unknown>) {
    return this.service.webhook(body, query);
  }
}
