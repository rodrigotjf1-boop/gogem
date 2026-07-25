import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { CategoriaModule } from './categoria/categoria.module';
import { ProdutoModule } from './produto/produto.module';
import { ComplementoModule } from './complemento/complemento.module';
import { RegemImportModule } from './integracoes/regem/regem-import.module';
import { TenantContextInterceptor } from './tenant/tenant-context.interceptor';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
    CategoriaModule,
    ProdutoModule,
    ComplementoModule,
    RegemImportModule,
  ],
  providers: [
    // Abre o contexto multi-tenant (AsyncLocalStorage) por requisição, após a
    // auth resolver req.user. Global: vale para todas as rotas.
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
})
export class AppModule {}
