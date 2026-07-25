import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateProdutoDto } from './dto/create-produto.dto';
import { ListProdutosQuery } from './dto/list-produtos.query';
import { SetExternalRefsDto } from './dto/set-external-refs.dto';
import { UpdateProdutoDto } from './dto/update-produto.dto';
import { ProdutoService } from './produto.service';

/**
 * Produtos do catálogo. Todas as rotas exigem autenticação (contexto de
 * tenant). Leitura: qualquer usuário. Escrita: gerente ou acima.
 */
@ApiTags('catalogo')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('produtos')
export class ProdutoController {
  constructor(private readonly produtos: ProdutoService) {}

  @Get()
  @ApiOkResponse({ description: 'Lista de produtos (filtros opcionais).' })
  list(@Query() query: ListProdutosQuery) {
    return this.produtos.list(query);
  }

  @Get(':id')
  @ApiOkResponse({ description: 'Produto por id.' })
  getOne(@Param('id') id: string) {
    return this.produtos.getOne(id);
  }

  @Post()
  @Roles('gerente')
  @ApiOkResponse({ description: 'Produto criado.' })
  create(@Body() dto: CreateProdutoDto) {
    return this.produtos.create(dto);
  }

  @Patch(':id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Produto atualizado.' })
  update(@Param('id') id: string, @Body() dto: UpdateProdutoDto) {
    return this.produtos.update(id, dto);
  }

  @Delete(':id')
  @Roles('gerente')
  @ApiOkResponse({ description: 'Produto removido.' })
  remove(@Param('id') id: string) {
    return this.produtos.remove(id);
  }

  @Put(':id/external-refs')
  @Roles('gerente')
  @ApiOkResponse({ description: 'De-para PDV substituído.' })
  setExternalRefs(@Param('id') id: string, @Body() dto: SetExternalRefsDto) {
    return this.produtos.setExternalRefs(id, dto.externalRefs);
  }
}
