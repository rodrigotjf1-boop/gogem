import { describe, expect, it, vi } from 'vitest';
import { TelemetriaService } from './telemetria.service';

describe('TelemetriaService', () => {
  it('registrar cria o evento sem tenantId (middleware injeta); default nivel=erro', async () => {
    const create = vi.fn().mockResolvedValue({});
    const prisma = { telemetriaEvento: { create } };
    const service = new TelemetriaService(prisma as any);

    await service.registrar('dev-1', { mensagem: 'boom' });

    const data = create.mock.calls[0][0].data;
    expect(data.dispositivoId).toBe('dev-1');
    expect(data.nivel).toBe('erro');
    expect(data.tenantId).toBeUndefined();
  });

  it('registrar trunca mensagem/detalhe longos', async () => {
    const create = vi.fn().mockResolvedValue({});
    const prisma = { telemetriaEvento: { create } };
    const service = new TelemetriaService(prisma as any);

    await service.registrar('dev-1', {
      mensagem: 'x'.repeat(1000),
      detalhe: 'y'.repeat(5000),
    });
    const data = create.mock.calls[0][0].data;
    expect(data.mensagem.length).toBe(500);
    expect(data.detalhe.length).toBe(4000);
  });

  it('listarOrg enriquece com nomes de dispositivo e loja (cross-tenant)', async () => {
    const eventos = [
      {
        id: 'e1',
        tenantId: 't1',
        dispositivoId: 'd1',
        nivel: 'erro',
        mensagem: 'falhou',
        detalhe: null,
        appVersao: '0.5.0',
        createdAt: new Date(),
      },
    ];
    const prisma = {
      telemetriaEvento: { findMany: vi.fn().mockResolvedValue(eventos) },
      dispositivo: {
        findMany: vi.fn().mockResolvedValue([{ id: 'd1', nome: 'Totem 1' }]),
      },
      tenant: {
        findMany: vi.fn().mockResolvedValue([{ id: 't1', nome: 'Mr Burguer' }]),
      },
    };
    const service = new TelemetriaService(prisma as any);

    const r = await service.listarOrg();
    expect(r[0].dispositivo).toBe('Totem 1');
    expect(r[0].loja).toBe('Mr Burguer');
    expect(r[0].mensagem).toBe('falhou');
  });
});
