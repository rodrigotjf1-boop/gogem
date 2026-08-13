import { UnauthorizedException } from '@nestjs/common';
import type { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthService } from '../src/auth/auth.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    tenant: { create: vi.fn() },
    usuario: { create: vi.fn(), findFirst: vi.fn(), findMany: vi.fn() },
  };
  const jwt = { sign: vi.fn().mockReturnValue('tok.jwt') };
  const service = new AuthService(
    prisma as unknown as PrismaService,
    jwt as unknown as JwtService,
  );
  return { service, prisma, jwt };
}

describe('bcryptjs', () => {
  it('hash + compare fazem roundtrip e o hash não é o texto puro', async () => {
    const hash = await bcrypt.hash('segredo123', 10);
    expect(hash).not.toBe('segredo123');
    expect(hash.startsWith('$2')).toBe(true);
    expect(await bcrypt.compare('segredo123', hash)).toBe(true);
    expect(await bcrypt.compare('errada', hash)).toBe(false);
  });
});

describe('AuthService.register', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cria tenant + usuário presidente com senha hasheada (não texto puro)', async () => {
    const { service, prisma, jwt } = makeService();
    prisma.tenant.create.mockResolvedValue({ id: 't-1', nome: 'Bar' });
    prisma.usuario.create.mockImplementation(
      async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'u-1',
        unidadeId: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        ...data,
      }),
    );

    const res = await service.register({
      empresa: 'Bar',
      nome: 'José',
      email: 'jose@bar.com',
      senha: 'segredo123',
    });

    expect(prisma.tenant.create).toHaveBeenCalledWith({
      data: { nome: 'Bar' },
    });
    const createArg = prisma.usuario.create.mock.calls[0][0].data;
    expect(createArg.papel).toBe('presidente');
    expect(createArg.tenantId).toBe('t-1');
    expect(createArg.senhaHash).not.toBe('segredo123');
    expect(await bcrypt.compare('segredo123', createArg.senhaHash)).toBe(true);

    // Token emitido e usuário sem hash na resposta.
    expect(res.access_token).toBe('tok.jwt');
    expect(res.user).not.toHaveProperty('senhaHash');
    expect(jwt.sign).toHaveBeenCalledWith({
      sub: 'u-1',
      tenant: 't-1',
      papel: 'presidente',
      email: 'jose@bar.com',
    });
  });
});

describe('AuthService.login', () => {
  beforeEach(() => vi.clearAllMocks());

  it('assina JWT com o payload correto quando a senha confere', async () => {
    const { service, prisma, jwt } = makeService();
    const senhaHash = await bcrypt.hash('segredo123', 10);
    prisma.usuario.findMany.mockResolvedValue([
      {
        id: 'u-9',
        tenantId: 't-9',
        nome: 'Ana',
        email: 'ana@bar.com',
        senhaHash,
        papel: 'gerente',
        unidadeId: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);

    const res = await service.login({
      email: 'ana@bar.com',
      senha: 'segredo123',
    });

    expect(jwt.sign).toHaveBeenCalledWith({
      sub: 'u-9',
      tenant: 't-9',
      papel: 'gerente',
      email: 'ana@bar.com',
    });
    expect(res.access_token).toBe('tok.jwt');
    expect(res.user).not.toHaveProperty('senhaHash');
  });

  it('rejeita senha incorreta com Unauthorized', async () => {
    const { service, prisma } = makeService();
    prisma.usuario.findMany.mockResolvedValue([
      {
        id: 'u-9',
        tenantId: 't-9',
        email: 'ana@bar.com',
        senhaHash: await bcrypt.hash('certa', 10),
        papel: 'gerente',
      },
    ]);
    await expect(
      service.login({ email: 'ana@bar.com', senha: 'errada' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejeita e-mail inexistente com Unauthorized', async () => {
    const { service, prisma } = makeService();
    prisma.usuario.findMany.mockResolvedValue([]);
    await expect(
      service.login({ email: 'x@y.com', senha: 'qualquer1' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('multi-tenant: mesmo e-mail em 2 lojas → loga na conta cuja senha casa', async () => {
    const { service, prisma, jwt } = makeService();
    // Duas contas com o MESMO e-mail (único por tenant), senhas diferentes.
    prisma.usuario.findMany.mockResolvedValue([
      {
        id: 'u-A',
        tenantId: 't-A',
        email: 'chef@rede.com',
        senhaHash: await bcrypt.hash('senhaA', 10),
        papel: 'gerente',
      },
      {
        id: 'u-B',
        tenantId: 't-B',
        email: 'chef@rede.com',
        senhaHash: await bcrypt.hash('senhaB', 10),
        papel: 'presidente',
      },
    ]);

    const res = await service.login({ email: 'chef@rede.com', senha: 'senhaB' });

    // Logou na conta do tenant B (a que a senha casa), não na primeira.
    expect(jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({ sub: 'u-B', tenant: 't-B' }),
    );
    expect(res.user).not.toHaveProperty('senhaHash');
  });
});
