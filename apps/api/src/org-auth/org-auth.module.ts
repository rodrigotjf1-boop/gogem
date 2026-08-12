import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { OrgAuthController } from './org-auth.controller';
import { OrgAuthGuard } from './org-auth.guard';
import { OrgAuthService } from './org-auth.service';
import { OrgJwtStrategy } from './org-jwt.strategy';

/**
 * OrgAuthModule — auth do Console da Distribuição (organização/DMS). Reusa o
 * `JWT_SECRET`, mas com estratégia 'org-jwt' própria (`tipo: 'org'`), separada
 * do login do cliente. Exporta o OrgAuthGuard para os módulos do console.
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
  controllers: [OrgAuthController],
  providers: [OrgAuthService, OrgJwtStrategy, OrgAuthGuard],
  exports: [OrgAuthGuard, OrgAuthService],
})
export class OrgAuthModule {}
