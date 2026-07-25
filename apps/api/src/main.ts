import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);

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

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

void bootstrap();
