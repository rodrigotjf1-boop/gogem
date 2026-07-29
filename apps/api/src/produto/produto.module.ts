import { Module } from '@nestjs/common';
import { CardapioModule } from '../cardapio/cardapio.module';
import { ProdutoController } from './produto.controller';
import { ProdutoService } from './produto.service';

@Module({
  imports: [CardapioModule],
  controllers: [ProdutoController],
  providers: [ProdutoService],
  exports: [ProdutoService],
})
export class ProdutoModule {}
