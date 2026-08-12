import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { CardapioModule } from './cardapio/cardapio.module';
import { AparenciaModule } from './aparencia/aparencia.module';
import { CategoriaModule } from './categoria/categoria.module';
import { ProdutoModule } from './produto/produto.module';
import { ComplementoModule } from './complemento/complemento.module';
import { CatalogoModule } from './catalogo/catalogo.module';
import { DispositivoModule } from './dispositivo/dispositivo.module';
import { MidiaModule } from './midia/midia.module';
import { RegemImportModule } from './integracoes/regem/regem-import.module';
import { IntegracaoModule } from './integracao/integracao.module';
import { VendasModule } from './vendas/vendas.module';
import { RelatorioModule } from './relatorio/relatorio.module';
import { OpenDeliveryModule } from './open-delivery/open-delivery.module';
import { KioskReleaseModule } from './kiosk-release/kiosk-release.module';
import { PagamentosModule } from './pagamentos/pagamentos.module';
import { OrgAuthModule } from './org-auth/org-auth.module';
import { TelemetriaModule } from './telemetria/telemetria.module';
import { TenantContextInterceptor } from './tenant/tenant-context.interceptor';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Rate limiting anti brute-force/abuso (padrão global; auth aperta mais —
    // ver AuthController). Armazenamento em memória: ok para 1 instância; com
    // múltiplas réplicas, trocar por storage compartilhado (Redis).
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    HealthModule,
    AuthModule,
    CardapioModule,
    AparenciaModule,
    CategoriaModule,
    ProdutoModule,
    ComplementoModule,
    CatalogoModule,
    DispositivoModule,
    MidiaModule,
    RegemImportModule,
    IntegracaoModule,
    VendasModule,
    RelatorioModule,
    OpenDeliveryModule,
    KioskReleaseModule,
    PagamentosModule,
    OrgAuthModule,
    TelemetriaModule,
  ],
  providers: [
    // Rate limiting global (por IP). Primeiro guard: barra o abuso antes de
    // qualquer lógica. Confia no X-Forwarded-For do proxy (ver main.ts).
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Abre o contexto multi-tenant (AsyncLocalStorage) por requisição, após a
    // auth resolver req.user. Global: vale para todas as rotas.
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
})
export class AppModule {}
