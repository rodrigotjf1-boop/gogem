import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { OdScope, OpenDeliveryAuthGuard } from './open-delivery-auth.guard';
import { CreateOpenDeliveryOrderDto } from './dto/create-order.dto';
import {
  AckEventsDto,
  UpdateOpenDeliveryOrderStatusDto,
} from './dto/update-order-status.dto';
import { OpenDeliveryOrderService } from './open-delivery-order.service';

/**
 * Rotas PÚBLICAS de pedidos + eventos do Open Delivery (Bearer do /oauth/token).
 * `orders:write` para criar/atualizar; `orders:read` para ler/pollar. Namespace
 * fora do /api/v1. O polling fica em `/events/polling` (o `:polling` do padrão
 * colide com params do Express).
 */
@ApiTags('open-delivery')
@UseGuards(OpenDeliveryAuthGuard)
@Controller('open-delivery/v1')
export class OpenDeliveryOrderController {
  constructor(private readonly orders: OpenDeliveryOrderService) {}

  @Post('orders')
  @OdScope('orders:write')
  criar(
    @Body() dto: CreateOpenDeliveryOrderDto,
    @Req() req: { user?: { userId?: string } },
  ) {
    return this.orders.ingest(dto, req.user?.userId);
  }

  @Get('orders/:id')
  @OdScope('orders:read')
  obter(@Param('id') id: string) {
    return this.orders.obter(id);
  }

  @Post('orders/:id/status')
  @OdScope('orders:write')
  status(
    @Param('id') id: string,
    @Body() dto: UpdateOpenDeliveryOrderStatusDto,
  ) {
    return this.orders.atualizarStatus(id, dto.status);
  }

  @Get('events/polling')
  @OdScope('orders:read')
  eventos(@Query('limit') limit?: string) {
    return this.orders.eventos(limit ? Number(limit) : undefined);
  }

  @Post('events/acknowledgment')
  @OdScope('orders:read')
  ack(@Body() dto: AckEventsDto) {
    return this.orders.ack(dto.ids);
  }
}
