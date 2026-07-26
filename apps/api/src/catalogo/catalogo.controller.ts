import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtOrDeviceGuard } from '../auth/jwt-or-device.guard';
import type { AuthenticatedUser } from '../auth/jwt.strategy';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CatalogoPublicacaoService } from './catalogo-publicacao.service';
import { PublicadoQuery } from './dto/publicado.query';

/**
 * Publicação versionada do catálogo (CLAUDE.md §3). Todas as rotas exigem
 * autenticação (contexto de tenant). Publicar: gerente ou acima (JWT). Listar
 * versões: qualquer usuário autenticado (JWT). Ler `/publicado`: JWT OU token
 * de dispositivo (totem) — o sync do totem passa por aqui (issue #12.1).
 *
 * Os guards são declarados POR MÉTODO (não na classe) justamente porque a
 * rota `/publicado` usa um guard diferente (JwtOrDeviceGuard) das demais.
 */
@ApiTags('catalogo-publicacao')
@ApiBearerAuth()
@Controller('catalogo')
export class CatalogoController {
  constructor(private readonly publicacao: CatalogoPublicacaoService) {}

  @Post('publicar')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('gerente')
  @ApiOkResponse({
    description: 'Congela o rascunho numa nova versão imutável do catálogo.',
  })
  publicar(@CurrentUser() user?: AuthenticatedUser) {
    return this.publicacao.publicar(user?.userId ?? null);
  }

  @Get('versoes')
  @UseGuards(JwtAuthGuard)
  @ApiOkResponse({
    description: 'Metadados das versões publicadas (sem o snapshot), recentes.',
  })
  listVersoes() {
    return this.publicacao.listVersoes();
  }

  @Get('publicado')
  @UseGuards(JwtOrDeviceGuard)
  @ApiOkResponse({
    description:
      'Última versão publicada (JWT ou X-Device-Token). Com ?desde, checa se o cliente está em dia.',
  })
  getPublicado(@Query() query: PublicadoQuery) {
    return this.publicacao.getPublicado(query.desde);
  }
}
