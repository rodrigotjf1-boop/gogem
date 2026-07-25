import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Resposta do healthcheck básico.
 */
export interface HealthStatus {
  status: 'ok';
  service: 'gogem-api';
  ts: string;
}

/**
 * Resposta do healthcheck do banco.
 */
export interface DbHealthStatus {
  db: 'up' | 'down';
  ts: string;
  error?: string;
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /** Liveness — não toca no banco. */
  @Get()
  @ApiOkResponse({ description: 'Serviço no ar.' })
  check(): HealthStatus {
    return { status: 'ok', service: 'gogem-api', ts: new Date().toISOString() };
  }

  /** Readiness do banco — roda `SELECT 1`. */
  @Get('db')
  @ApiOkResponse({ description: 'Estado da conexão com o banco.' })
  async checkDb(): Promise<DbHealthStatus> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { db: 'up', ts: new Date().toISOString() };
    } catch (err) {
      return {
        db: 'down',
        ts: new Date().toISOString(),
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }
}
