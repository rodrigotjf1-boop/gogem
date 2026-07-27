import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiOkResponse, ApiSecurity, ApiTags } from '@nestjs/swagger';
import { DeviceCtx } from '../auth/device-ctx.decorator';
import {
  DEVICE_TOKEN_HEADER,
  DeviceTokenGuard,
} from '../auth/device-token.guard';
import type { DeviceUser } from '../auth/device-token.guard';
import { VendaTotemDto } from './dto/venda-totem.dto';
import { VendasService } from './vendas.service';

/**
 * Venda de totem (issue #12.2). O totem fala SÓ com o GoGeM e se autentica por
 * `X-Device-Token` (DeviceTokenGuard, reusado do #14): o guard resolve o tenant
 * do dispositivo e o TenantContextInterceptor abre o contexto multi-tenant. O
 * GoGeM repassa a venda ao Regem guardando o token do Regem no servidor.
 */
@ApiTags('vendas')
@ApiSecurity(DEVICE_TOKEN_HEADER)
@UseGuards(DeviceTokenGuard)
@Controller('vendas')
export class VendasController {
  constructor(private readonly vendas: VendasService) {}

  @Post()
  @ApiOkResponse({
    description:
      'Registra a venda do totem e a lança no Regem (idempotente por idempotencyKey).',
  })
  registrar(@DeviceCtx() ctx: DeviceUser, @Body() dto: VendaTotemDto) {
    return this.vendas.registrarVendaTotem(
      {
        tenantId: ctx.tenantId,
        deviceId: ctx.deviceId,
        unidadeId: ctx.unidadeId,
      },
      dto,
    );
  }
}
