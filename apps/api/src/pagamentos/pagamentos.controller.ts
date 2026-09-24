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
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { DeviceCtx } from '../auth/device-ctx.decorator';
import { DeviceTokenGuard } from '../auth/device-token.guard';
import type { DeviceUser } from '../auth/device-token.guard';
import {
  CancelamentoService,
  PRAZO_ESTORNO_TOTEM_MS,
} from './cancelamento.service';
import { CriarPixDto } from './dto/criar-pix.dto';
import { EstornoTotemDto } from './dto/estorno-totem.dto';
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
    private readonly cancelamento: CancelamentoService,
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

  // Resultado fiscal (Regem #574): o pagamento foi APROVADO, mas a venda não se concluiu —
  // a NFC-e não foi emitida (`nao_emitida`) ou o cupom fiscal não imprimiu. O totem pede o
  // estorno pelo orderId (uuid do pedido); no servidor da loja a chamada chega pelo repasse
  // `pagamentos/estorno` do Regem, que não tem as credenciais do Mercado Pago. Idempotente.
  @Post('estorno')
  @HttpCode(200)
  @UseGuards(DeviceTokenGuard)
  @ApiOkResponse({
    description:
      'Estorna o pagamento aprovado de um pedido do totem e registra o motivo no relatório.',
  })
  estornar(@DeviceCtx() ctx: DeviceUser, @Body() dto: EstornoTotemDto) {
    return this.cancelamento.estornarPorOrder(
      dto.orderId,
      dto.motivo,
      'totem',
      {
        prazoMs: PRAZO_ESTORNO_TOTEM_MS,
        etapa: dto.etapa,
        registro: {
          dispositivoId: ctx.deviceId,
          senha: dto.senha ?? null,
          itens: dto.itens,
        },
      },
    );
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
