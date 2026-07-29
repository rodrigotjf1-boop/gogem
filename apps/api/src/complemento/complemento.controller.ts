import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ComplementoService } from './complemento.service';
import { CreateGrupoDto } from './dto/create-grupo.dto';
import { CreateOpcaoDto } from './dto/create-opcao.dto';
import { ReordenarDto } from './dto/reordenar.dto';
import { UpdateGrupoDto } from './dto/update-grupo.dto';
import { UpdateOpcaoDto } from './dto/update-opcao.dto';

/**
 * Complementos do catálogo — etapas REUTILIZÁVEIS + opções. Leitura: qualquer
 * usuário autenticado. Escrita: gerente+.
 */
@ApiTags('catalogo')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class ComplementoController {
  constructor(private readonly complementos: ComplementoService) {}

  // --- Etapas de um produto (via vínculo) ---------------------------------

  @Get('produtos/:produtoId/grupos')
  @ApiOkResponse({ description: 'Etapas vinculadas ao produto (com opções).' })
  listGrupos(@Param('produtoId') produtoId: string) {
    return this.complementos.listGrupos(produtoId);
  }

  @Post('produtos/:produtoId/grupos')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Etapa nova criada e vinculada ao produto.' })
  createGrupo(
    @Param('produtoId') produtoId: string,
    @Body() dto: CreateGrupoDto,
  ) {
    return this.complementos.createGrupo(produtoId, dto);
  }

  @Post('produtos/:produtoId/grupos/:grupoId/anexar')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Vincula uma etapa existente (reutilizar).' })
  anexar(
    @Param('produtoId') produtoId: string,
    @Param('grupoId') grupoId: string,
  ) {
    return this.complementos.anexar(produtoId, grupoId);
  }

  @Delete('produtos/:produtoId/grupos/:grupoId')
  @Roles('gerente')
  @ApiOkResponse({
    description: 'Desvincula a etapa do produto (não a apaga).',
  })
  desanexar(
    @Param('produtoId') produtoId: string,
    @Param('grupoId') grupoId: string,
  ) {
    return this.complementos.desanexar(produtoId, grupoId);
  }

  @Patch('produtos/:produtoId/grupos/:grupoId/ordem')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Reordena a etapa dentro do produto.' })
  reordenar(
    @Param('produtoId') produtoId: string,
    @Param('grupoId') grupoId: string,
    @Body() dto: ReordenarDto,
  ) {
    return this.complementos.reordenar(produtoId, grupoId, dto.ordem);
  }

  // --- Catálogo de etapas reutilizáveis -----------------------------------

  @Get('complementos')
  @ApiOkResponse({ description: 'Etapas reutilizáveis do tenant (com usos).' })
  listReutilizaveis() {
    return this.complementos.listReutilizaveis();
  }

  @Post('complementos')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Cria uma etapa reutilizável (sem vincular).' })
  createReutilizavel(@Body() dto: CreateGrupoDto) {
    return this.complementos.createReutilizavel(dto);
  }

  @Patch('grupos/:id')
  @Roles('gerente')
  @ApiOkResponse({
    description: 'Atualiza a etapa (reflete em todos os usos).',
  })
  updateGrupo(@Param('id') id: string, @Body() dto: UpdateGrupoDto) {
    return this.complementos.updateGrupo(id, dto);
  }

  @Delete('grupos/:id')
  @Roles('gerente')
  @ApiOkResponse({
    description: 'Exclui a etapa reutilizável (opções+vínculos).',
  })
  removeGrupo(@Param('id') id: string) {
    return this.complementos.removeGrupo(id);
  }

  // --- Opções (aninhadas na etapa) ----------------------------------------

  @Post('grupos/:grupoId/opcoes')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Opção criada sob a etapa.' })
  createOpcao(@Param('grupoId') grupoId: string, @Body() dto: CreateOpcaoDto) {
    return this.complementos.createOpcao(grupoId, dto);
  }

  @Patch('opcoes/:id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Opção atualizada.' })
  updateOpcao(@Param('id') id: string, @Body() dto: UpdateOpcaoDto) {
    return this.complementos.updateOpcao(id, dto);
  }

  @Delete('opcoes/:id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Opção removida.' })
  removeOpcao(@Param('id') id: string) {
    return this.complementos.removeOpcao(id);
  }
}
