import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { OrgAuthGuard } from '../org-auth/org-auth.guard';
import { TelemetriaService } from './telemetria.service';

/**
 * Telemetria no Console da Distribuição — leitura CROSS-TENANT dos eventos de
 * toda a frota (organização/DMS). Base `/org/telemetria`.
 */
@ApiTags('org')
@UseGuards(OrgAuthGuard)
@Controller('org/telemetria')
export class TelemetriaOrgController {
  constructor(private readonly service: TelemetriaService) {}

  @Get('eventos')
  eventos(@Query('limite') limite?: string) {
    const n = Number(limite);
    return this.service.listarOrg(Number.isFinite(n) && n > 0 ? n : 200);
  }
}
