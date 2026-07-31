import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateOpenDeliveryAppDto } from './dto/create-app.dto';
import { OpenDeliveryAppService } from './open-delivery-app.service';

/**
 * Gestão dos apps parceiros do Open Delivery (interno, /api/v1). Só gerente+
 * cadastra/revoga. O clientSecret aparece só na criação. As rotas PÚBLICAS que
 * os parceiros consomem ficam em `/open-delivery/v1/*`.
 */
@ApiTags('open-delivery')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('gerente')
@Controller('open-delivery-apps')
export class OpenDeliveryAppController {
  constructor(private readonly apps: OpenDeliveryAppService) {}

  @Post()
  criar(@Body() dto: CreateOpenDeliveryAppDto) {
    return this.apps.criar(dto);
  }

  @Get()
  listar() {
    return this.apps.listar();
  }

  @Delete(':id')
  revogar(@Param('id') id: string) {
    return this.apps.revogar(id);
  }
}
