import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CancelamentoService } from '../src/pagamentos/cancelamento.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { PspResolver } from '../src/pagamentos/psp/psp-resolver';
import type { AuditoriaService } from '../src/auditoria/auditoria.service';

function makeService() {
  const prisma = {
    pedido: { findFirst: vi.fn(), update: vi.fn().mockResolvedValue({}) },
    pointPayment: {
      findFirst: vi.fn().mockResolvedValue(null),
      update: vi.fn().mockResolvedValue({}),
    },
    pixCharge: {
      findFirst: vi.fn().mockResolvedValue(null),
      update: vi.fn().mockResolvedValue({}),
    },
  };
  const gw = { reembolsar: vi.fn() };
  const psp = { resolver: vi.fn().mockResolvedValue(gw) };
  const auditoria = { registrar: vi.fn() };
  const service = new CancelamentoService(
    prisma as unknown as PrismaService,
    psp as unknown as PspResolver,
    auditoria as unknown as AuditoriaService,
  );
  return { service, prisma, psp, gw, auditoria };
}

const PEDIDO = {
  id: 'ped1',
  idempotencyKey: 'idem1',
  status: 'enviado',
  totalCentavos: 3000,
};

describe('CancelamentoService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cartão aprovado → estorna no MP (refund_<key>), marca refunded + cancelado', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue({
      id: 'pp1',
      status: 'approved',
      paymentId: 'MP123',
      tipo: 'credito',
      amountCents: 3000,
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'REF1', status: 'approved' });

    const res = await service.cancelarPorId(
      'ped1',
      'cliente desistiu',
      'admin',
    );

    expect(gw.reembolsar).toHaveBeenCalledWith('MP123', 'refund_idem1');
    expect(prisma.pointPayment.update).toHaveBeenCalledWith({
      where: { id: 'pp1' },
      data: { status: 'refunded' },
    });
    expect(prisma.pedido.update.mock.calls.at(-1)?.[0].data.status).toBe(
      'cancelado',
    );
    expect(res.estorno).toMatchObject({
      feito: true,
      meio: 'credito',
      valorCentavos: 3000,
      refundId: 'REF1',
    });
  });

  it('PIX aprovado → estorna pelo pspRef', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      idempotencyKey: 'idem5',
      totalCentavos: 2500,
    });
    prisma.pixCharge.findFirst.mockResolvedValue({
      id: 'px5',
      status: 'approved',
      pspRef: 'PIXREF',
      amountCents: 2500,
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'RPIX', status: 'approved' });

    const res = await service.cancelarPorId('ped1', 'x', 'admin');

    expect(gw.reembolsar).toHaveBeenCalledWith('PIXREF', 'refund_idem5');
    expect(res.estorno).toMatchObject({
      feito: true,
      meio: 'pix',
      refundId: 'RPIX',
    });
  });

  it('dinheiro (sem pagamento eletrônico) → cancela sem estornar', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      totalCentavos: 4200,
    });

    const res = await service.cancelarPorId('ped1', 'x', 'regem');

    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(res.estorno.feito).toBe(false);
    expect(res.estorno.meio).toBe('dinheiro');
    expect(res.estorno.valorCentavos).toBe(4200);
    expect(prisma.pedido.update.mock.calls.at(-1)?.[0].data.status).toBe(
      'cancelado',
    );
  });

  it('já cancelado → idempotente: não estorna nem atualiza', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      status: 'cancelado',
    });

    const res = await service.cancelarPorId('ped1', 'x', 'admin');

    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.update).not.toHaveBeenCalled();
    expect(res.estorno.feito).toBe(false);
  });

  it('refund falha → cancela mesmo assim; estorno.feito=false; NÃO lança', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue({
      id: 'pp4',
      status: 'approved',
      paymentId: 'MP9',
      tipo: 'debito',
      amountCents: 3000,
    });
    gw.reembolsar.mockRejectedValue(new Error('MP 400'));

    const res = await service.cancelarPorId('ped1', 'x', 'admin');

    expect(res.estorno.feito).toBe(false);
    expect(prisma.pointPayment.update).not.toHaveBeenCalled(); // só marca refunded se feito
    expect(prisma.pedido.update.mock.calls.at(-1)?.[0].data.status).toBe(
      'cancelado',
    );
  });

  it('cancelarPorChave sem idempotencyKey nem regemComandaId → 400', async () => {
    const { service } = makeService();
    await expect(service.cancelarPorChave({}, 'x', 'regem')).rejects.toThrow();
  });
});
