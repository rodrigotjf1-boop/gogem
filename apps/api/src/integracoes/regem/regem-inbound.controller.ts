import { Body, Controller, Headers, HttpCode, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { CancelarTotemDto } from './dto/cancelar-totem.dto';
import { RegemInboundService } from './regem-inbound.service';

/**
 * Entrada PUSH do Regem. Público — autentica pelo `X-Sync-Token` da própria
 * integração (não JWT). `publicar` = sync imediato do catálogo;
 * `pedido-cancelado` = cancela o pedido do totem + estorna o cartão/PIX no MP.
 */
@ApiTags('integracoes')
@Controller('sync/regem')
export class RegemInboundController {
  constructor(private readonly inbound: RegemInboundService) {}

  @Post('publicar')
  @HttpCode(200)
  publicar(@Headers('x-sync-token') token: string) {
    return this.inbound.publicar(token ?? '');
  }

  @Post('pedido-cancelado')
  @HttpCode(200)
  pedidoCancelado(
    @Headers('x-sync-token') token: string,
    @Body() dto: CancelarTotemDto,
  ) {
    return this.inbound.cancelarPedido(token ?? '', dto);
  }
}
