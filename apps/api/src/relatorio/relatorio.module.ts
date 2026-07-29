import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RelatorioController } from './relatorio.controller';
import { RelatorioService } from './relatorio.service';

/**
 * RelatorioModule — relatórios operacionais (Fase 7). PrismaService é global;
 * AuthModule fornece os guards (JWT + Roles).
 */
@Module({
  imports: [AuthModule],
  controllers: [RelatorioController],
  providers: [RelatorioService],
})
export class RelatorioModule {}
