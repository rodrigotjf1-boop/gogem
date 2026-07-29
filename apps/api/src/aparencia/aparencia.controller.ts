import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AparenciaService } from './aparencia.service';
import { UpdateAparenciaDto } from './dto/update-aparencia.dto';

/**
 * Aparência do totem (Fase 6). Leitura: qualquer usuário autenticado. Escrita:
 * gerente+. O totem consome pelo `/catalogo/publicado`.
 */
@ApiTags('aparencia')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('aparencia')
export class AparenciaController {
  constructor(private readonly service: AparenciaService) {}

  @Get()
  obter() {
    return this.service.obter();
  }

  @Put()
  @Roles('gerente')
  atualizar(@Body() dto: UpdateAparenciaDto) {
    return this.service.atualizar(dto);
  }
}
