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
import { UpdateGrupoDto } from './dto/update-grupo.dto';
import { UpdateOpcaoDto } from './dto/update-opcao.dto';

/**
 * Complementos do catálogo (fatia 2b): grupos (etapas) aninhados no produto e
 * suas opções. Todas as rotas exigem autenticação (contexto de tenant).
 * Leitura: qualquer usuário. Escrita: gerente ou acima.
 *
 * Sem prefixo de classe: cada método declara sua rota (produtos/:id/grupos,
 * grupos/:id, grupos/:id/opcoes, opcoes/:id).
 */
@ApiTags('catalogo')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class ComplementoController {
  constructor(private readonly complementos: ComplementoService) {}

  // --- Grupos (aninhados no produto) --------------------------------------

  @Get('produtos/:produtoId/grupos')
  @ApiOkResponse({ description: 'Grupos do produto (com opções), ordenados.' })
  listGrupos(@Param('produtoId') produtoId: string) {
    return this.complementos.listGrupos(produtoId);
  }

  @Post('produtos/:produtoId/grupos')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Grupo criado sob o produto.' })
  createGrupo(
    @Param('produtoId') produtoId: string,
    @Body() dto: CreateGrupoDto,
  ) {
    return this.complementos.createGrupo(produtoId, dto);
  }

  @Patch('grupos/:id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Grupo atualizado.' })
  updateGrupo(@Param('id') id: string, @Body() dto: UpdateGrupoDto) {
    return this.complementos.updateGrupo(id, dto);
  }

  @Delete('grupos/:id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Grupo removido (com suas opções).' })
  removeGrupo(@Param('id') id: string) {
    return this.complementos.removeGrupo(id);
  }

  // --- Opções (aninhadas no grupo) ----------------------------------------

  @Post('grupos/:grupoId/opcoes')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Opção criada sob o grupo.' })
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
