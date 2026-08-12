import { describe, expect, it, vi } from 'vitest';
import * as bcrypt from 'bcryptjs';
import { OrgAuthService } from './org-auth.service';

function montar(
  user: {
    id?: string;
    email?: string;
    senhaHash: string;
    nome?: string;
    papel?: string;
    ativo?: boolean;
  } | null,
) {
  const prisma = {
    orgUsuario: { findUnique: vi.fn().mockResolvedValue(user) },
  };
  const jwt = { sign: vi.fn().mockReturnValue('TOKEN') };
  const service = new OrgAuthService(prisma as any, jwt as any);
  return { service, prisma, jwt };
}

describe('OrgAuthService.login', () => {
  it('senha correta → token + user sem hash, payload tipo=org', async () => {
    const senhaHash = await bcrypt.hash('segredo123', 10);
    const h = montar({
      id: 'o1',
      email: 'dms@gogem.com.br',
      senhaHash,
      nome: 'DMS',
      papel: 'admin',
      ativo: true,
    });
    const r = await h.service.login({
      email: 'dms@gogem.com.br',
      senha: 'segredo123',
    });
    expect(r.access_token).toBe('TOKEN');
    expect((r.user as any).senhaHash).toBeUndefined();
    expect(h.jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({ tipo: 'org', sub: 'o1', papel: 'admin' }),
    );
  });

  it('senha errada → 401', async () => {
    const senhaHash = await bcrypt.hash('certa', 10);
    const h = montar({ senhaHash, ativo: true });
    await expect(
      h.service.login({ email: 'x@y.com', senha: 'errada' }),
    ).rejects.toThrow('Credenciais inválidas.');
  });

  it('usuário inexistente → 401 (mensagem genérica)', async () => {
    const h = montar(null);
    await expect(
      h.service.login({ email: 'nao@existe.com', senha: 'qualquer' }),
    ).rejects.toThrow('Credenciais inválidas.');
  });

  it('usuário inativo → 401', async () => {
    const senhaHash = await bcrypt.hash('segredo123', 10);
    const h = montar({ senhaHash, ativo: false });
    await expect(
      h.service.login({ email: 'x@y.com', senha: 'segredo123' }),
    ).rejects.toThrow('Credenciais inválidas.');
  });
});
