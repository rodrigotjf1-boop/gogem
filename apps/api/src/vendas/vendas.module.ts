import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RegemModule } from '../integracoes/regem/regem.module';
import { VendasController } from './vendas.controller';
import { VendasService } from './vendas.service';

/**
 * VendasModule — venda de totem repassada ao Regem (issue #12.2).
 *
 * Importa o AuthModule (provê o DeviceTokenGuard reusado do #14) e o RegemModule
 * (RegemSalesClient + resolver de config por tenant). PrismaService vem do
 * PrismaModule global.
 */
@Module({
  imports: [AuthModule, RegemModule],
  controllers: [VendasController],
  providers: [VendasService],
  exports: [VendasService],
})
export class VendasModule {}
