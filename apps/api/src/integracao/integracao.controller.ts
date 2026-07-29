import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import {
  IntegracaoService,
  type IntegracaoView,
  type TesteResultado,
} from './integracao.service';
import { UpsertIntegracaoDto } from './dto/upsert-integracao.dto';
import type { RegemImportResumo } from '../integracoes/regem/regem-import.service';

/**
 * Integrações (Fase 2). Área de conectores do GoGeM — API aberta. Escrita e
 * ações (testar/importar) exigem gerente+. Tudo roda no tenant do chamador (§2).
 */
@ApiTags('integracoes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('gerente')
@Controller('integracoes')
export class IntegracaoController {
  constructor(private readonly service: IntegracaoService) {}

  /** Lista os conectores com o estado do tenant (segredos mascarados). */
  @Get()
  list(): Promise<IntegracaoView[]> {
    return this.service.list();
  }

  /** Salva a config de um conector. */
  @Put(':tipo')
  upsert(
    @Param('tipo') tipo: string,
    @Body() dto: UpsertIntegracaoDto,
  ): Promise<IntegracaoView> {
    return this.service.upsert(tipo, dto);
  }

  /** Testa a conexão do conector. */
  @Post(':tipo/testar')
  testar(@Param('tipo') tipo: string): Promise<TesteResultado> {
    return this.service.testar(tipo);
  }

  /** Importa o catálogo do sistema externo para o rascunho do GoGeM. */
  @Post(':tipo/importar')
  importar(@Param('tipo') tipo: string): Promise<RegemImportResumo> {
    return this.service.importar(tipo);
  }
}
