import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardapioModule } from '../cardapio/cardapio.module';
import { CatalogoController } from './catalogo.controller';
import { CatalogoPublicacaoService } from './catalogo-publicacao.service';

@Module({
  // AuthModule exporta os guards (JwtAuthGuard/JwtOrDeviceGuard) usados por rota.
  imports: [AuthModule, CardapioModule],
  controllers: [CatalogoController],
  providers: [CatalogoPublicacaoService],
  exports: [CatalogoPublicacaoService],
})
export class CatalogoModule {}
