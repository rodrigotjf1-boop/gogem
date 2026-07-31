import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { OpenDeliveryTokenDto } from './dto/token.dto';
import { OpenDeliveryTokenService } from './open-delivery-token.service';

/**
 * Token OAuth2 do Open Delivery (público, FORA do /api/v1). O parceiro troca
 * clientId/clientSecret por um access_token curto usado nas demais rotas OD.
 */
@ApiTags('open-delivery')
@Controller('open-delivery/v1/oauth')
export class OpenDeliveryTokenController {
  constructor(private readonly tokens: OpenDeliveryTokenService) {}

  @Post('token')
  @HttpCode(200)
  token(@Body() dto: OpenDeliveryTokenDto) {
    return this.tokens.emitir(dto);
  }
}
