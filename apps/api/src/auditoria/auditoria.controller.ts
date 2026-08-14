import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AuditoriaService } from './auditoria.service';

/**
 * Leitura da trilha de auditoria. Só o PRESIDENTE (topo da hierarquia) vê — é
 * dado sensível de governança. Tenant-scoped: cada empresa vê só a sua.
 */
@ApiTags('auditoria')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('presidente')
@Controller('auditoria')
export class AuditoriaController {
  constructor(private readonly service: AuditoriaService) {}

  @Get()
  @ApiOkResponse({
    description: 'Trilha de auditoria (mais recente primeiro).',
  })
  listar(@Query('limite') limite?: string) {
    return this.service.listar(limite ? Number(limite) : 200);
  }
}
