import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
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
import { LojaDoRegemDto, VoltaDoRegemDto } from './dto/clique-regem.dto';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/jwt.strategy';
import { RegemCliqueService } from '../integracoes/regem/regem-clique.service';
import type { RegemImportResumo } from '../integracoes/regem/regem-import.service';
import type { SituacaoDosAvisos } from '../integracoes/regem/regem-avisos.service';

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
  constructor(
    private readonly service: IntegracaoService,
    private readonly clique: RegemCliqueService,
  ) {}

  /** Lista os conectores com o estado do tenant (segredos mascarados). */
  @Get()
  list(): Promise<IntegracaoView[]> {
    return this.service.list();
  }

  /**
   * "Conectar pelo Regem" (Hub DMS F6): abre o pedido no Regem e devolve a página de lá, para
   * onde o navegador vai. Quem autoriza é o presidente da empresa, no Regem.
   */
  @Post('regem/clique')
  conectarPeloRegem(
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<{ url: string }> {
    return this.clique.iniciar(user);
  }

  /** A volta do Regem: troca o código pela ligação de cada loja marcada (ou registra a recusa). */
  @Post('regem/clique/volta')
  voltaDoRegem(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: VoltaDoRegemDto,
  ) {
    return this.clique.concluir(user, dto);
  }

  /** Troca a loja do Regem em uso (entre as que o presidente ligou). */
  @Post('regem/clique/loja')
  escolherLojaDoRegem(@Body() dto: LojaDoRegemDto) {
    return this.clique.escolher(dto.lojaId);
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

  /**
   * Desliga os avisos assinados do Regem (o Regem volta na hora ao caminho antigo).
   * Religar = "Testar conexão".
   */
  @Post(':tipo/avisos/desligar')
  desligarAvisos(@Param('tipo') tipo: string): Promise<SituacaoDosAvisos> {
    return this.service.desligarAvisos(tipo);
  }

  /** Importa o catálogo do sistema externo para o cardápio-alvo (ou o ativo). */
  @Post(':tipo/importar')
  importar(
    @Param('tipo') tipo: string,
    @Query('cardapioId') cardapioId?: string,
  ): Promise<RegemImportResumo> {
    return this.service.importar(tipo, cardapioId);
  }
}
