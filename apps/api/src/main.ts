import 'reflect-metadata';
import { RequestMethod, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);

  // Atrás do proxy do EasyPanel (1 hop): confia no X-Forwarded-For para o
  // rate-limit enxergar o IP real do cliente (senão todos compartilham o IP do
  // proxy). `1` = exatamente um proxy confiável.
  const expressApp = app.getHttpAdapter().getInstance() as {
    set: (k: string, v: unknown) => void;
  };
  expressApp.set('trust proxy', 1);

  // Prefixo global — CLAUDE.md: API pública versionada em /api/v1. O namespace
  // Open Delivery é público e versionado por conta própria em `/open-delivery/v1`
  // (padrão de mercado), então fica FORA do prefixo interno.
  app.setGlobalPrefix('api/v1', {
    exclude: [{ path: 'open-delivery/v1/(.*)', method: RequestMethod.ALL }],
  });

  // Segurança básica de headers.
  app.use(helmet());

  // CORS: o painel (admin) roda em outro domínio (ex.: app.gogem.com.br) e precisa
  // chamar esta API. Sempre liberamos a FAMÍLIA própria (*.gogem.com.br) — assim
  // trocar de subdomínio nunca derruba o admin — além das origens extras em
  // CORS_ORIGIN (lista por vírgula). Sem lista (dev), reflete a origem. Auth é por
  // Bearer (não cookie), então liberar a origem não expõe sessão de terceiros.
  const listaCors = (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  const origemPermitida = (origin?: string): boolean => {
    if (!origin) return true; // apps nativos / curl (sem header Origin)
    let host = '';
    try {
      host = new URL(origin).hostname;
    } catch {
      return false;
    }
    if (host === 'gogem.com.br' || host.endsWith('.gogem.com.br')) return true;
    if (listaCors.includes(origin)) return true;
    return listaCors.length === 0; // dev sem lista: permissivo (como antes)
  };
  app.enableCors({
    origin: (origin, cb) => cb(null, origemPermitida(origin)),
    credentials: true,
  });

  // Validação global: rejeita campos não declarados e transforma payloads.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // OpenAPI — fonte da verdade do contrato (alimenta packages/contracts).
  // Em PRODUÇÃO fica FECHADO por padrão (não expor o contrato/rotas ao público):
  // só liga com SWAGGER_ENABLED=true. Fora de produção, sempre ligado.
  const swaggerLigado =
    process.env.SWAGGER_ENABLED === 'true' ||
    process.env.NODE_ENV !== 'production';
  if (swaggerLigado) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('GoGeM API')
      .setDescription(
        'API núcleo do GoGeM by DMS — autoatendimento food service.',
      )
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/v1/docs', app, document);
  }

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

void bootstrap();
