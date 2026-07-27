import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { RegemSalesClient } from '../integracoes/regem/regem-sales.client';
import { VendasController } from './vendas.controller';
import { VendasService } from './vendas.service';

/**
 * VendasModule — venda de totem repassada ao Regem (issue #12.2).
 *
 * Importa o AuthModule (provê o DeviceTokenGuard reusado do #14) e o
 * ConfigModule (base/token do Regem via env). PrismaService vem do
 * PrismaModule global.
 */
@Module({
  imports: [AuthModule, ConfigModule],
  controllers: [VendasController],
  providers: [RegemSalesClient, VendasService],
  exports: [VendasService],
})
export class VendasModule {}
