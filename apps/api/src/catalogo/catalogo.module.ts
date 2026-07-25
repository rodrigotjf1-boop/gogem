import { Module } from '@nestjs/common';
import { CatalogoController } from './catalogo.controller';
import { CatalogoPublicacaoService } from './catalogo-publicacao.service';

@Module({
  controllers: [CatalogoController],
  providers: [CatalogoPublicacaoService],
  exports: [CatalogoPublicacaoService],
})
export class CatalogoModule {}
