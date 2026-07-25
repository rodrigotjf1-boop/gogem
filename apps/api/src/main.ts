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
