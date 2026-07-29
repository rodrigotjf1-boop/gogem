import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardapioController } from './cardapio.controller';
import { CardapioService } from './cardapio.service';

/**
 * CardapioModule — cardápios do tenant (Fase 3B). Exporta o CardapioService
 * para os módulos de catálogo (categoria/produto/publicação/import) resolverem
 * o cardápio-alvo/ativo. PrismaService é global.
 */
@Module({
  imports: [AuthModule],
  controllers: [CardapioController],
  providers: [CardapioService],
  exports: [CardapioService],
})
export class CardapioModule {}
