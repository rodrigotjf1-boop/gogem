import {
  BadRequestException,
  Controller,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../auth/roles.decorator';
import { RolesGuard } from '../../auth/roles.guard';
import {
  RegemImportService,
  type RegemImportResumo,
} from './regem-import.service';

/**
 * Import do catálogo do Regem (fatia 3). Rota JWT-guarded — o import roda no
 * contexto de tenant do chamador (§2). Escrita de catálogo: gerente ou acima.
 */
@ApiTags('integracao-regem')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('import/regem')
export class RegemImportController {
  constructor(
    private readonly service: RegemImportService,
    private readonly config: ConfigService,
  ) {}

  @Post()
  @Roles('gerente')
  @ApiOkResponse({
    description:
      'Resumo do import: categorias/produtos/grupos/opções criados e atualizados.',
  })
  async importar(): Promise<RegemImportResumo> {
    const base = this.config.get<string>('REGEM_API_BASE');
    const token = this.config.get<string>('REGEM_SYNC_TOKEN');
    if (!base || !token) {
      throw new BadRequestException(
        'Integração Regem não configurada: defina REGEM_API_BASE e REGEM_SYNC_TOKEN no ambiente da API.',
      );
    }
    return this.service.importar();
  }
}
