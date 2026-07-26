import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DeviceTokenGuard, DeviceUser } from '../src/auth/device-token.guard';
import type { PrismaService } from '../src/prisma/prisma.service';

interface FakeReq {
  headers: Record<string, unknown>;
  user?: DeviceUser;
}

function makeCtx(req: FakeReq): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => req }),
  } as unknown as ExecutionContext;
}

function makeGuard() {
  const prisma = { dispositivo: { findFirst: vi.fn() } };
  const guard = new DeviceTokenGuard(prisma as unknown as PrismaService);
  return { guard, prisma };
}

describe('DeviceTokenGuard', () => {
  beforeEach(() => vi.clearAllMocks());

  it('token válido (pareado + ativo) → seta req.user com tenantId e libera', async () => {
    const { guard, prisma } = makeGuard();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      tenantId: 't-9',
      unidadeId: 'u-2',
      pareado: true,
      ativo: true,
    });
    const req: FakeReq = { headers: { 'x-device-token': 'tok-abc' } };

    await expect(guard.canActivate(makeCtx(req))).resolves.toBe(true);
    // req.user materializado para o TenantContextInterceptor abrir o contexto.
    expect(req.user).toEqual({
      userId: null,
      tenantId: 't-9',
      papel: 'dispositivo',
      deviceId: 'd-1',
      unidadeId: 'u-2',
    });
    // lookup feito pelo token do header.
    expect(prisma.dispositivo.findFirst).toHaveBeenCalledWith({
      where: { token: 'tok-abc' },
    });
  });

  it('header ausente → Unauthorized (sem tocar o banco)', async () => {
    const { guard, prisma } = makeGuard();
    const req: FakeReq = { headers: {} };
    await expect(guard.canActivate(makeCtx(req))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(prisma.dispositivo.findFirst).not.toHaveBeenCalled();
    expect(req.user).toBeUndefined();
  });

  it('token inexistente → Unauthorized', async () => {
    const { guard, prisma } = makeGuard();
    prisma.dispositivo.findFirst.mockResolvedValue(null);
    const req: FakeReq = { headers: { 'x-device-token': 'nope' } };
    await expect(guard.canActivate(makeCtx(req))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('revogado (ativo=false) → Unauthorized', async () => {
    const { guard, prisma } = makeGuard();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      tenantId: 't-9',
      unidadeId: null,
      pareado: true,
      ativo: false,
    });
    const req: FakeReq = { headers: { 'x-device-token': 'tok' } };
    await expect(guard.canActivate(makeCtx(req))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(req.user).toBeUndefined();
  });

  it('não pareado → Unauthorized', async () => {
    const { guard, prisma } = makeGuard();
    prisma.dispositivo.findFirst.mockResolvedValue({
      id: 'd-1',
      tenantId: 't-9',
      unidadeId: null,
      pareado: false,
      ativo: true,
    });
    const req: FakeReq = { headers: { 'x-device-token': 'tok' } };
    await expect(guard.canActivate(makeCtx(req))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
