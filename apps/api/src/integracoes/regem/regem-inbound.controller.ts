import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Param,
  Post,
  Req,
  type RawBodyRequest,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import type { IncomingMessage } from 'node:http';
import { CancelarTotemDto } from './dto/cancelar-totem.dto';
import { RegemInboundService } from './regem-inbound.service';
import { RegemAvisosService } from './regem-avisos.service';

/**
 * Entrada PUSH do Regem. Pública — sem JWT.
 *  • Caminho NOVO (contrato 1 dos avisos assinados, fase 3 da credencial própria):
 *    `POST /sync/regem/avisos/:id` — o Regem assina no padrão Standard Webhooks; o GoGeM confere
 *    sobre o corpo EXATO (por isso o `rawBody` no `main.ts`) antes de qualquer coisa, e só então
 *    trata `pedido.cancelado` ou `catalogo.publicar`. O `X-Sync-Token` que ainda chega junto não
 *    autentica nada aqui.
 *  • Caminho antigo (até a fase 4 do Regem), pelo `X-Sync-Token` da integração: `publicar` = sync
 *    imediato do catálogo; `pedido-cancelado` = cancela o pedido do totem + estorna no MP.
 */
@ApiTags('integracoes')
@Controller('sync/regem')
export class RegemInboundController {
  constructor(
    private readonly inbound: RegemInboundService,
    private readonly avisos: RegemAvisosService,
  ) {}

  @Post('avisos/:id')
  @HttpCode(200)
  async aviso(
    @Param('id') id: string,
    @Req() req: RawBodyRequest<IncomingMessage>,
    @Headers() cabecalhos: Record<string, string | string[] | undefined>,
  ) {
    // Sem o corpo cru não há como conferir: melhor recusar do que conferir o JSON remontado.
    const corpoCru = req.rawBody ? req.rawBody.toString('utf8') : '';
    const aviso = await this.avisos.conferir(id, cabecalhos, corpoCru);
    return this.inbound.tratarAviso(aviso);
  }

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
