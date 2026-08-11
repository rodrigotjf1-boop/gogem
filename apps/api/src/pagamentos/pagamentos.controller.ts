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
import { CriarPixDto } from './dto/criar-pix.dto';
import { PagamentosService } from './pagamentos.service';
import { PointService } from './point.service';

/**
 * Pagamentos PIX (F8). O totem cria a cobrança e faz polling do status; o PSP
 * confirma por webhook. O tenant vem do X-Device-Token (contexto multi-tenant);
 * o webhook é público (o PSP chama) e casa pelo pspRef.
 */
@ApiTags('pagamentos')
@Controller('pagamentos')
export class PagamentosController {
  constructor(
    private readonly service: PagamentosService,
    private readonly point: PointService,
  ) {}

  // F10: status do pagamento por orderId (uuid do pedido) — o totem usa no boot
  // pra reconciliar pendências (pagou mas não sincronizou?). Checa Point e PIX.
  @Get('status/:orderId')
  @UseGuards(DeviceTokenGuard)
  async statusPorOrder(@Param('orderId') orderId: string) {
    const point = await this.point.statusPorOrder(orderId);
    if (point) return { tipo: 'point', status: point.status };
    const pix = await this.service.statusPixPorOrder(orderId);
    if (pix) return { tipo: 'pix', status: pix.status };
    return { tipo: 'nenhum', status: 'nenhum' };
  }

  @Post('pix')
  @UseGuards(DeviceTokenGuard)
  criar(@Body() dto: CriarPixDto) {
    return this.service.criarPix(dto);
  }

  @Get('pix/:id')
  @UseGuards(DeviceTokenGuard)
  status(@Param('id') id: string) {
    return this.service.statusPix(id);
  }

  // Webhook do PSP — público (o PSP não manda X-Device-Token). Não confia no
  // corpo: só extrai a referência e re-consulta o status no PSP.
  @Post('pix/webhook')
  @HttpCode(200)
  webhook(@Body() body: unknown, @Query() query: Record<string, unknown>) {
    return this.service.webhook(body, query);
  }
}
