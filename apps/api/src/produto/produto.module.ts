import { Module } from '@nestjs/common';
import { CardapioModule } from '../cardapio/cardapio.module';
import { RegemModule } from '../integracoes/regem/regem.module';
import { ProdutoController } from './produto.controller';
import { ProdutoService } from './produto.service';

@Module({
  imports: [CardapioModule, RegemModule],
  controllers: [ProdutoController],
  providers: [ProdutoService],
  exports: [ProdutoService],
})
export class ProdutoModule {}
