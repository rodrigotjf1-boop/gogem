import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/jwt.strategy';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CatalogoPublicacaoService } from './catalogo-publicacao.service';
import { PublicadoQuery } from './dto/publicado.query';

/**
 * Publicação versionada do catálogo (CLAUDE.md §3). Todas as rotas exigem
 * autenticação (contexto de tenant). Publicar: gerente ou acima. Leitura de
 * versões/publicado: qualquer usuário autenticado.
 *
 * NOTE (S2/S3): a leitura de `/publicado` é hoje protegida por JWT; a auth do
 * dispositivo/totem (pareamento via `X-Sync-Token`) que guardará o sync é um
 * follow-up — TODO trocar o guard desta rota quando existir.
 */
@ApiTags('catalogo-publicacao')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('catalogo')
export class CatalogoController {
  constructor(private readonly publicacao: CatalogoPublicacaoService) {}

  @Post('publicar')
  @Roles('gerente')
  @ApiOkResponse({
    description: 'Congela o rascunho numa nova versão imutável do catálogo.',
  })
  publicar(@CurrentUser() user?: AuthenticatedUser) {
    return this.publicacao.publicar(user?.userId ?? null);
  }

  @Get('versoes')
  @ApiOkResponse({
    description: 'Metadados das versões publicadas (sem o snapshot), recentes.',
  })
  listVersoes() {
    return this.publicacao.listVersoes();
  }

  @Get('publicado')
  @ApiOkResponse({
    description:
      'Última versão publicada. Com ?desde, checa se o cliente está em dia.',
  })
  getPublicado(@Query() query: PublicadoQuery) {
    return this.publicacao.getPublicado(query.desde);
  }
}
