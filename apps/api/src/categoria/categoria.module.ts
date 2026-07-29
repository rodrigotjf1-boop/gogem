import { Module } from '@nestjs/common';
import { CardapioModule } from '../cardapio/cardapio.module';
import { CategoriaController } from './categoria.controller';
import { CategoriaService } from './categoria.service';

@Module({
  imports: [CardapioModule],
  controllers: [CategoriaController],
  providers: [CategoriaService],
  exports: [CategoriaService],
})
export class CategoriaModule {}
