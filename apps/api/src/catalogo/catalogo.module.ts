import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardapioModule } from '../cardapio/cardapio.module';
import { AparenciaModule } from '../aparencia/aparencia.module';
import { RegemModule } from '../integracoes/regem/regem.module';
import { CatalogoController } from './catalogo.controller';
import { CatalogoPublicacaoService } from './catalogo-publicacao.service';

@Module({
  // AuthModule exporta os guards (JwtAuthGuard/JwtOrDeviceGuard) usados por rota.
  // RegemModule: o resolver diz se a loja é integrada (a publicação deixa de fora o que
  // não tem código PDV).
  imports: [AuthModule, CardapioModule, AparenciaModule, RegemModule],
  controllers: [CatalogoController],
  providers: [CatalogoPublicacaoService],
  exports: [CatalogoPublicacaoService],
})
export class CatalogoModule {}
