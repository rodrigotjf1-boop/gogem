import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { TenantContext } from '../src/tenant/tenant-context';
import { DeviceTokenGuard } from '../src/auth/device-token.guard';
import { resumoDoTokenDoDispositivo } from '../src/auth/token-do-dispositivo';
import { DispositivoService } from '../src/dispositivo/dispositivo.service';

/**
 * Prova contra um Postgres DE VERDADE (opt-in): a migration que troca os tokens
 * dos totens pelo resumo e o guarda aceitando o mesmo token depois dela.
 * Rodar num banco DESCARTÁVEL já migrado (`prisma migrate deploy`):
 *   TOKEN_TOTEM_PG_URL=postgresql://…/banco_descartavel?schema=public npx vitest run test/token-totem.pg.spec.ts
 * Apaga os dispositivos e os tenants "totem-…" desse banco.
 */
const URL = process.env.TOKEN_TOTEM_PG_URL;
const MIGRATION = join(
  __dirname,
  '../prisma/migrations/20261015010000_dispositivo_token_resumo/migration.sql',
);

describe.skipIf(!URL)('token do totem só como resumo — Postgres real', () => {
  let prisma: PrismaService;
  let tenantId = '';
  // Callback async: com o síncrono a consulta roda fora do contexto (ERR-031).
  const sistema = <T>(fn: () => Promise<T>) =>
    TenantContext.runAsSystem(async () => {
      const r = await fn();
      return r;
    });
  const entrar = async (token: string) => {
    const req: { headers: Record<string, unknown>; user?: any } = {
      headers: { 'x-device-token': token },
    };
    const ctx = {
      switchToHttp: () => ({ getRequest: () => req }),
    } as unknown as ExecutionContext;
    await new DeviceTokenGuard(prisma).canActivate(ctx);
    return req.user;
  };

  beforeAll(async () => {
    process.env.DATABASE_URL = URL;
    prisma = new PrismaService();
    await prisma.$connect();
    await sistema(async () => {
      await prisma.dispositivo.deleteMany({});
      await prisma.tenant.deleteMany({
        where: { nome: { startsWith: 'totem-' } },
      });
      tenantId = (await prisma.tenant.create({ data: { nome: 'totem-a' } })).id;
      // Como está hoje em produção: o token em claro na coluna "token".
      await prisma.dispositivo.create({
        data: {
          tenantId,
          nome: 'Totem antigo',
          pareado: true,
          ativo: true,
          tokenHash: 'token-antigo-do-totem',
        },
      });
    });
  });

  afterAll(async () => {
    await prisma?.$disconnect();
  });

  it('a migration troca o token pelo resumo, uma vez só', async () => {
    const sql = readFileSync(MIGRATION, 'utf8');
    await prisma.$executeRawUnsafe(sql);
    await prisma.$executeRawUnsafe(sql); // segunda vez: não converte de novo
    const linhas = await prisma.$queryRawUnsafe<{ token: string }[]>(
      `select "token" from "dispositivos" where "nome" = 'Totem antigo'`,
    );
    expect(linhas).toEqual([
      { token: resumoDoTokenDoDispositivo('token-antigo-do-totem') },
    ]);
  });

  it('o totem já pareado entra com o MESMO token, sem parear de novo', async () => {
    const user = await entrar('token-antigo-do-totem');
    expect(user.tenantId).toBe(tenantId);
  });

  it('o resumo guardado no banco não serve de token', async () => {
    await expect(
      entrar(resumoDoTokenDoDispositivo('token-antigo-do-totem')),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('pareamento novo grava só o resumo e o token devolvido entra', async () => {
    const svc = new DispositivoService(prisma);
    await sistema(() =>
      prisma.dispositivo.create({
        data: {
          tenantId,
          nome: 'Totem novo',
          codigoPareamento: '482913',
          codigoExpiraEm: new Date(Date.now() + 60_000),
        },
      }),
    );
    const r = await svc.parear('482913');
    const linhas = await prisma.$queryRawUnsafe<{ token: string }[]>(
      `select "token" from "dispositivos" where "nome" = 'Totem novo'`,
    );
    expect(linhas[0]!.token).toBe(resumoDoTokenDoDispositivo(r.token));
    expect(linhas[0]!.token).not.toContain(r.token);
    expect((await entrar(r.token)).tenantId).toBe(tenantId);
  });
});
