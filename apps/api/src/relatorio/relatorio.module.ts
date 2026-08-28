import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PagamentosModule } from '../pagamentos/pagamentos.module';
import { RelatorioController } from './relatorio.controller';
import { RelatorioService } from './relatorio.service';

/**
 * RelatorioModule — relatórios operacionais (Fase 7). PrismaService é global;
 * AuthModule fornece os guards (JWT + Roles); PagamentosModule fornece o
 * CancelamentoService (cancelar + estorno).
 */
@Module({
  imports: [AuthModule, PagamentosModule],
  controllers: [RelatorioController],
  providers: [RelatorioService],
})
export class RelatorioModule {}
