import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { DispositivoService } from './dispositivo.service';
import { CreateDispositivoDto } from './dto/create-dispositivo.dto';

/**
 * Admin de dispositivos (totens) — issue #12.1. Todas as rotas exigem gerente
 * ou acima (RBAC no servidor, CLAUDE.md). O contexto de tenant vem do JWT via
 * TenantContextInterceptor; o middleware isola as queries pelo `tenantId`.
 */
@ApiTags('dispositivos')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('gerente')
@Controller('dispositivos')
export class DispositivoController {
  constructor(private readonly dispositivos: DispositivoService) {}

  @Post()
  @ApiOkResponse({
    description:
      'Cria o dispositivo (não pareado) e emite um código de pareamento de 6 dígitos (uso único, 15 min).',
  })
  create(@Body() dto: CreateDispositivoDto) {
    return this.dispositivos.create(dto);
  }

  @Get()
  @ApiOkResponse({ description: 'Dispositivos do tenant (sem o token).' })
  list() {
    return this.dispositivos.list();
  }

  @Post(':id/revogar')
  @ApiOkResponse({ description: 'Revoga o dispositivo (ativo = false).' })
  revogar(@Param('id') id: string) {
    return this.dispositivos.revogar(id);
  }

  @Post(':id/reparear')
  @ApiOkResponse({
    description: 'Gera um novo código de pareamento e limpa o token anterior.',
  })
  reparear(@Param('id') id: string) {
    return this.dispositivos.reparear(id);
  }
}
