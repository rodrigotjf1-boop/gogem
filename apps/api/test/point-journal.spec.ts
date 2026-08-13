import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PointService } from '../src/pagamentos/point.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { PspResolver } from '../src/pagamentos/psp/psp-resolver';

function makeService() {
  const prisma = {
    pointPayment: {
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    pointJournal: {
      create: vi.fn().mockResolvedValue({}),
      findMany: vi.fn().mockResolvedValue([]),
    },
    dispositivo: { findFirst: vi.fn() },
  };
  const pspResolver = {
    resolverPoint: vi.fn(),
    tokenMercadoPago: vi.fn(),
  };
  const service = new PointService(
    prisma as unknown as PrismaService,
    pspResolver as unknown as PspResolver,
  );
  return { service, prisma, pspResolver };
}

const pp = {
  id: 'pp-1',
  tenantId: 't-1',
  orderId: 'ord-1',
  deviceId: 'dev-1',
  intentId: 'int-1',
  amountCents: 1000,
  tipo: 'credit',
  bandeira: null,
  status: 'pending',
  paymentId: null,
};

describe('PointService — F10 journal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cancelar (pending) grava um evento no journal com origem=cancelar', async () => {
    const { service, prisma, pspResolver } = makeService();
    prisma.pointPayment.findFirst.mockResolvedValue({ ...pp });
    pspResolver.resolverPoint.mockResolvedValue({
      deviceId: 'dev-1',
      cancelar: vi.fn().mockResolvedValue(undefined),
    });
    prisma.pointPayment.update.mockResolvedValue({
      ...pp,
      status: 'cancelled',
    });

    await service.cancelar('pp-1');

    expect(prisma.pointJournal.create).toHaveBeenCalledTimes(1);
    expect(prisma.pointJournal.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        pointPaymentId: 'pp-1',
        orderId: 'ord-1',
        deviceId: 'dev-1',
        status: 'cancelled',
        origem: 'cancelar',
      }),
    });
  });

  it('journal é best-effort: falha no create NÃO derruba o cancelamento', async () => {
    const { service, prisma, pspResolver } = makeService();
    prisma.pointPayment.findFirst.mockResolvedValue({ ...pp });
    pspResolver.resolverPoint.mockResolvedValue({
      deviceId: 'dev-1',
      cancelar: vi.fn().mockResolvedValue(undefined),
    });
    prisma.pointPayment.update.mockResolvedValue({
      ...pp,
      status: 'cancelled',
    });
    prisma.pointJournal.create.mockRejectedValue(new Error('db down'));

    const res = await service.cancelar('pp-1');
    expect(res.status).toBe('cancelled'); // não lançou
  });

  it('journal(orderId) busca em ordem cronológica; sem orderId, os mais recentes', async () => {
    const { service, prisma } = makeService();

    await service.journal('ord-1');
    expect(prisma.pointJournal.findMany).toHaveBeenCalledWith({
      where: { orderId: 'ord-1' },
      orderBy: { createdAt: 'asc' },
      take: 200,
    });

    await service.journal();
    expect(prisma.pointJournal.findMany).toHaveBeenCalledWith({
      where: {},
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  });
});
