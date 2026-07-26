import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { DeviceTokenGuard } from './device-token.guard';
import { JwtAuthGuard } from './jwt-auth.guard';
import { JwtOrDeviceGuard } from './jwt-or-device.guard';
import { JwtStrategy } from './jwt.strategy';

/**
 * AuthModule — JWT (segredo em JWT_SECRET, expira em 12h) + estratégia
 * passport-jwt. RolesGuard/JwtAuthGuard são usados por rota via @UseGuards.
 */
@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: '12h' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    JwtAuthGuard,
    DeviceTokenGuard,
    JwtOrDeviceGuard,
  ],
  exports: [AuthService, JwtAuthGuard, DeviceTokenGuard, JwtOrDeviceGuard],
})
export class AuthModule {}
