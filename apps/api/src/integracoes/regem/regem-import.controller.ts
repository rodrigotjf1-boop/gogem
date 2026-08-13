import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
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

  @Get('novidades')
  @Roles('gerente')
  @ApiOkResponse({
    description:
      'Diferenças Regem×GoGeM: novos (a importar) e órfãos (sumiram do Regem).',
  })
  novidades() {
    return this.service.novidades();
  }

  @Post('ignorar')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Marca um código do Regem como ignorado.' })
  ignorar(@Body() body: { codigo?: string }) {
    return this.service.ignorarNovidade(body?.codigo ?? '');
  }

  @Get('conflitos')
  @Roles('gerente')
  @ApiOkResponse({
    description: 'Conflitos abertos (loja é a fonte e o Regem diverge).',
  })
  conflitos() {
    return this.service.conflitos();
  }

  @Post('conflitos/:id/resolver')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Resolve um conflito (regem | gogem).' })
  resolverConflito(
    @Param('id') id: string,
    @Body() body: { escolha?: 'regem' | 'gogem' },
  ) {
    return this.service.resolverConflito(
      id,
      body?.escolha === 'gogem' ? 'gogem' : 'regem',
    );
  }
}
