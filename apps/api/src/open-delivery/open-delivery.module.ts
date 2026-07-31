import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AuthModule } from '../auth/auth.module';
import { CatalogoModule } from '../catalogo/catalogo.module';
import { OpenDeliveryAppController } from './open-delivery-app.controller';
import { OpenDeliveryAppService } from './open-delivery-app.service';
import { OpenDeliveryAuthGuard } from './open-delivery-auth.guard';
import { OpenDeliveryCatalogController } from './open-delivery-catalog.controller';
import { OpenDeliveryCatalogService } from './open-delivery-catalog.service';
import { OpenDeliveryOrderController } from './open-delivery-order.controller';
import { OpenDeliveryOrderService } from './open-delivery-order.service';
import { OpenDeliveryTokenController } from './open-delivery-token.controller';
import { OpenDeliveryTokenService } from './open-delivery-token.service';

/**
 * OpenDeliveryModule — modo PROVEDOR Open Delivery (GoGeM expõe a API pública em
 * `/open-delivery/v1`). OD-1: autenticação (apps + token OAuth2). Reusa o
 * JWT_SECRET, mas emite tokens curtos (1h) com audiência própria. PrismaService
 * é global; AuthModule fornece os guards da gestão interna.
 */
@Module({
  imports: [
    AuthModule,
    CatalogoModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: '1h' },
      }),
    }),
  ],
  controllers: [
    OpenDeliveryAppController,
    OpenDeliveryTokenController,
    OpenDeliveryCatalogController,
    OpenDeliveryOrderController,
  ],
  providers: [
    OpenDeliveryAppService,
    OpenDeliveryTokenService,
    OpenDeliveryCatalogService,
    OpenDeliveryOrderService,
    OpenDeliveryAuthGuard,
  ],
  exports: [OpenDeliveryAuthGuard, JwtModule],
})
export class OpenDeliveryModule {}
