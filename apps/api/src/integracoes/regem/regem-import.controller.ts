import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../auth/roles.decorator';
import { RolesGuard } from '../../auth/roles.guard';
import { RegemConfigResolver } from './regem-config.resolver';
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
    private readonly regem: RegemConfigResolver,
  ) {}

  @Post()
  @Roles('gerente')
  @ApiOkResponse({
    description:
      'Resumo do import: categorias/produtos/grupos/opções criados e atualizados.',
  })
  async importar(): Promise<RegemImportResumo> {
    await this.exigirIntegracao();
    return this.service.importar();
  }

  @Get('novidades')
  @Roles('gerente')
  @ApiOkResponse({
    description:
      'Diferenças Regem×GoGeM: novos (a importar) e órfãos (sumiram do Regem).',
  })
  async novidades() {
    // O Catálogo do painel pede as novidades sempre que abre: na empresa sem Regem, a falta
    // da integração é resposta esperada (400), não erro do servidor com pilha no log (ERR-051).
    await this.exigirIntegracao();
    return this.service.novidades();
  }

  /**
   * A integração é a DA EMPRESA de quem pede — antes o import exigia as envs globais, e recusava
   * a empresa com integração própria quando elas não existiam (ERR-012). Sem ela → 400 com o
   * motivo. A recusa que já é HTTP (a cifra que não abre = 503) passa como veio.
   */
  private async exigirIntegracao(): Promise<void> {
    await this.regem.resolve().catch((e: unknown) => {
      if (e instanceof HttpException) throw e;
      throw new BadRequestException(
        e instanceof Error ? e.message : 'Integração Regem não configurada.',
      );
    });
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
