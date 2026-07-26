import { ExecutionContext } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { DeviceTokenGuard } from '../src/auth/device-token.guard';
import type { JwtAuthGuard } from '../src/auth/jwt-auth.guard';
import { JwtOrDeviceGuard } from '../src/auth/jwt-or-device.guard';

function makeCtx(headers: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ headers }) }),
  } as unknown as ExecutionContext;
}

function makeGuard() {
  const jwt = { canActivate: vi.fn().mockReturnValue(true) };
  const device = { canActivate: vi.fn().mockResolvedValue(true) };
  const guard = new JwtOrDeviceGuard(
    jwt as unknown as JwtAuthGuard,
    device as unknown as DeviceTokenGuard,
  );
  return { guard, jwt, device };
}

describe('JwtOrDeviceGuard', () => {
  beforeEach(() => vi.clearAllMocks());

  it('com X-Device-Token → usa o DeviceTokenGuard (não o JWT)', async () => {
    const { guard, jwt, device } = makeGuard();
    await expect(
      guard.canActivate(makeCtx({ 'x-device-token': 'tok' })),
    ).resolves.toBe(true);
    expect(device.canActivate).toHaveBeenCalledOnce();
    expect(jwt.canActivate).not.toHaveBeenCalled();
  });

  it('sem X-Device-Token → cai no JwtAuthGuard (smoke-test com Bearer)', async () => {
    const { guard, jwt, device } = makeGuard();
    await expect(
      guard.canActivate(makeCtx({ authorization: 'Bearer x' })),
    ).resolves.toBe(true);
    expect(jwt.canActivate).toHaveBeenCalledOnce();
    expect(device.canActivate).not.toHaveBeenCalled();
  });
});
