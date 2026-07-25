import { describe, expect, it, vi } from 'vitest';
import { HealthController } from '../src/health/health.controller';
import type { PrismaService } from '../src/prisma/prisma.service';

describe('HealthController', () => {
  // Sem DB: o liveness não toca no Prisma; passamos um stub mínimo.
  const prismaStub = {
    $queryRaw: vi.fn(),
  } as unknown as PrismaService;

  const controller = new HealthController(prismaStub);

  it('GET /health retorna status ok', () => {
    const res = controller.check();
    expect(res.status).toBe('ok');
    expect(res.service).toBe('gogem-api');
    expect(typeof res.ts).toBe('string');
  });

  it('GET /health/db reporta down quando o SELECT 1 falha', async () => {
    (
      prismaStub.$queryRaw as unknown as ReturnType<typeof vi.fn>
    ).mockRejectedValueOnce(new Error('no db'));
    const res = await controller.checkDb();
    expect(res.db).toBe('down');
    expect(res.error).toContain('no db');
  });
});
