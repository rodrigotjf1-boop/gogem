import { Controller, Headers, HttpCode, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { RegemInboundService } from './regem-inbound.service';

/**
 * Entrada PUSH do Regem ("Publicar no GoGeM"). Público — autentica pelo
 * `X-Sync-Token` da própria integração (não JWT). Dispara o sync imediato dos
 * produtos linkados + republicação.
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
}
