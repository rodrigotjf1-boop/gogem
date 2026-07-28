import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
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

  // Prefixo global — CLAUDE.md: API pública versionada em /api/v1.
  app.setGlobalPrefix('api/v1');

  // Segurança básica de headers.
  app.use(helmet());

  // CORS: o painel (admin) roda em outro domínio (ex.: admin-stg.gogem.com.br) e
  // precisa chamar esta API. CORS_ORIGIN = lista de origens separadas por vírgula;
  // sem a var (dev), reflete a origem da requisição. Auth é por Bearer (não cookie).
  const corsOrigin = process.env.CORS_ORIGIN;
  app.enableCors({
    origin: corsOrigin ? corsOrigin.split(',').map((o) => o.trim()) : true,
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
