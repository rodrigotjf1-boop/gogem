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
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CategoriaService } from './categoria.service';
import { CreateCategoriaDto } from './dto/create-categoria.dto';
import { UpdateCategoriaDto } from './dto/update-categoria.dto';

/**
 * Categorias do catálogo. Todas as rotas exigem autenticação (JwtAuthGuard) —
 * necessário para o contexto de tenant. Leitura: qualquer usuário. Escrita:
 * gerente ou acima (RolesGuard + @Roles).
 */
@ApiTags('catalogo')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('categorias')
export class CategoriaController {
  constructor(private readonly categorias: CategoriaService) {}

  @Get()
  @ApiOkResponse({ description: 'Lista de categorias do tenant.' })
  list() {
    return this.categorias.list();
  }

  @Get(':id')
  @ApiOkResponse({ description: 'Categoria por id.' })
  getOne(@Param('id') id: string) {
    return this.categorias.getOne(id);
  }

  @Post()
  @Roles('gerente')
  @ApiOkResponse({ description: 'Categoria criada.' })
  create(@Body() dto: CreateCategoriaDto) {
    return this.categorias.create(dto);
  }

  @Patch(':id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Categoria atualizada.' })
  update(@Param('id') id: string, @Body() dto: UpdateCategoriaDto) {
    return this.categorias.update(id, dto);
  }

  @Delete(':id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Categoria removida (409 se tiver produtos).' })
  remove(@Param('id') id: string) {
    return this.categorias.remove(id);
  }
}
