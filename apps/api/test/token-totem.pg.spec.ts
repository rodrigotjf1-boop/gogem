import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { TenantContext } from '../src/tenant/tenant-context';
import { DeviceTokenGuard } from '../src/auth/device-token.guard';
import { resumoDoTokenDoDispositivo } from '../src/auth/token-do-dispositivo';
import { DispositivoService } from '../src/dispositivo/dispositivo.service';

/**
 * Prova contra um Postgres DE VERDADE (opt-in): na transição, o totem pareado
 * antes (token puro na coluna) e o pareado agora (só o resumo) entram, e o
 * resumo copiado do banco não serve de token.
 * Rodar num banco DESCARTÁVEL já migrado (`prisma migrate deploy`):
 *   TOKEN_TOTEM_PG_URL=postgresql://…/banco_descartavel?schema=public npx vitest run test/token-totem.pg.spec.ts
 * Apaga os dispositivos e os tenants "totem-…" desse banco.
 */
const URL = process.env.TOKEN_TOTEM_PG_URL;

describe.skipIf(!URL)('token do totem como resumo — Postgres real', () => {
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
  const colunaToken = async (nome: string) => {
    const linhas = await prisma.$queryRawUnsafe<{ token: string }[]>(
      `select "token" from "dispositivos" where "nome" = $1`,
      nome,
    );
    return linhas[0]!.token;
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
      // Como está hoje em produção: o token puro na coluna "token".
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

  it('o totem pareado antes entra com o MESMO token, sem parear de novo', async () => {
    const user = await entrar('token-antigo-do-totem');
    expect(user.tenantId).toBe(tenantId);
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
    const guardado = await colunaToken('Totem novo');
    expect(guardado).toBe(resumoDoTokenDoDispositivo(r.token));
    expect(guardado).not.toContain(r.token);
    expect((await entrar(r.token)).tenantId).toBe(tenantId);
  });

  it('o resumo copiado do banco não serve de token', async () => {
    const guardado = await colunaToken('Totem novo');
    await expect(entrar(guardado)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
