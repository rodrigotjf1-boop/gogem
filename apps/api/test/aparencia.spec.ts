import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AparenciaService } from '../src/aparencia/aparencia.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    aparencia: {
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
  };
  const service = new AparenciaService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('AparenciaService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('obter cria a aparência padrão quando não existe (sem tenantId manual)', async () => {
    const { service, prisma } = makeService();
    prisma.aparencia.findFirst.mockResolvedValue(null);
    prisma.aparencia.create.mockResolvedValue({ id: 'ap-1' });
    await service.obter();
    expect(prisma.aparencia.create).toHaveBeenCalledTimes(1);
    // Colunas usam @default; nada de tenantId à mão (middleware injeta).
    expect(
      JSON.stringify(prisma.aparencia.create.mock.calls[0][0]),
    ).not.toContain('tenantId');
  });

  it('obter devolve a existente sem recriar', async () => {
    const { service, prisma } = makeService();
    prisma.aparencia.findFirst.mockResolvedValue({ id: 'ap-1' });
    await expect(service.obter()).resolves.toEqual({ id: 'ap-1' });
    expect(prisma.aparencia.create).not.toHaveBeenCalled();
  });

  it('atualizar aplica o patch e serializa descansoMidias', async () => {
    const { service, prisma } = makeService();
    prisma.aparencia.findFirst.mockResolvedValue({ id: 'ap-1' });
    prisma.aparencia.update.mockResolvedValue({ id: 'ap-1' });
    await service.atualizar({
      corPrimaria: '#FF0000',
      temaPreset: 'brasa',
      descansoTipo: 'carrossel',
      descansoMidias: [
        {
          url: 'https://x/img.png',
          tipo: 'imagem',
          kicker: 'Feito na brasa',
          titulo: 'Mister Double',
          subtitulo: 'Dois blends',
        },
      ],
    });
    const arg = prisma.aparencia.update.mock.calls[0][0];
    expect(arg.where).toEqual({ id: 'ap-1' });
    expect(arg.data.corPrimaria).toBe('#FF0000');
    expect(arg.data.temaPreset).toBe('brasa'); // preset de tema (F3)
    expect(arg.data.descansoTipo).toBe('carrossel');
    // Legendas por slide (F3) preservadas no Json.
    expect(arg.data.descansoMidias).toEqual([
      {
        url: 'https://x/img.png',
        tipo: 'imagem',
        kicker: 'Feito na brasa',
        titulo: 'Mister Double',
        subtitulo: 'Dois blends',
      },
    ]);
  });

  it('atualizar sem descansoMidias não mexe no campo (undefined)', async () => {
    const { service, prisma } = makeService();
    prisma.aparencia.findFirst.mockResolvedValue({ id: 'ap-1' });
    prisma.aparencia.update.mockResolvedValue({ id: 'ap-1' });
    await service.atualizar({ corFundo: '#000000' });
    expect(
      prisma.aparencia.update.mock.calls[0][0].data.descansoMidias,
    ).toBeUndefined();
  });
});
