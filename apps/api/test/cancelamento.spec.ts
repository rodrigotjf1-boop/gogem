import { Prisma } from '@prisma/client';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  CancelamentoService,
  PRAZO_ESTORNO_TOTEM_MS,
} from '../src/pagamentos/cancelamento.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { PspResolver } from '../src/pagamentos/psp/psp-resolver';
import type { AuditoriaService } from '../src/auditoria/auditoria.service';
import {
  RegemRecusouError,
  type RegemSalesClient,
} from '../src/integracoes/regem/regem-sales.client';

function makeService() {
  const prisma = {
    pedido: {
      findFirst: vi.fn(),
      update: vi.fn().mockResolvedValue({}),
      create: vi.fn().mockResolvedValue({ id: 'novo' }),
    },
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
  const regem = {
    cancelarVendaExterna: vi
      .fn()
      .mockResolvedValue({ status: 'sem_integracao' }),
  };
  const service = new CancelamentoService(
    prisma as unknown as PrismaService,
    psp as unknown as PspResolver,
    auditoria as unknown as AuditoriaService,
    regem as unknown as RegemSalesClient,
  );
  return { service, prisma, psp, gw, auditoria, regem };
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

describe('CancelamentoService.estornarPorOrder — resultado fiscal do totem', () => {
  beforeEach(() => vi.clearAllMocks());

  const agora = () => new Date();
  const POINT_APROVADO = {
    id: 'pp1',
    status: 'approved',
    paymentId: 'MP1',
    tipo: 'debito',
    amountCents: 4500,
  };

  it('NUVEM (pedido existe) → cancela com o motivo fiscal e estorna', async () => {
    const { service, prisma, gw, auditoria } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      totalCentavos: 4500,
    });
    prisma.pointPayment.findFirst.mockResolvedValue({
      ...POINT_APROVADO,
      createdAt: agora(),
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'R9', status: 'approved' });

    const r = await service.estornarPorOrder(
      'idem1',
      'NFC-e não emitida (rejeitada 778): NCM',
      'totem',
      { etapa: 'rejeitada', prazoMs: PRAZO_ESTORNO_TOTEM_MS },
    );

    expect(gw.reembolsar).toHaveBeenCalledWith('MP1', 'refund_idem1');
    expect(r).toMatchObject({ pedidoId: 'ped1', estorno: { feito: true } });
    const upd = prisma.pedido.update.mock.calls.at(-1)?.[0].data;
    expect(upd).toMatchObject({
      status: 'cancelado',
      canceladoMotivo: 'NFC-e não emitida (rejeitada 778): NCM',
    });
    expect(prisma.pedido.create).not.toHaveBeenCalled();
    expect(auditoria.registrar.mock.calls.at(-1)?.[0].detalhe).toMatchObject({
      origem: 'totem',
      etapa: 'rejeitada',
    });
  });

  it('SERVIDOR DA LOJA (nuvem só tem o pagamento) → estorna e CRIA o pedido cancelado para o relatório', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    prisma.pointPayment.findFirst.mockResolvedValue({
      ...POINT_APROVADO,
      createdAt: agora(),
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'R1', status: 'approved' });

    const r = await service.estornarPorOrder(
      'uuid-1',
      'Cupom fiscal não impresso no totem: sem papel',
      'totem',
      {
        etapa: 'impressao',
        registro: {
          dispositivoId: 'dev-7',
          senha: 12,
          itens: [{ codigoPdv: 'X1', quantidade: 2 }],
        },
      },
    );

    expect(r.estorno).toMatchObject({ feito: true, refundId: 'R1' });
    const criado = prisma.pedido.create.mock.calls[0][0].data;
    expect(criado).toMatchObject({
      idempotencyKey: 'uuid-1',
      status: 'cancelado',
      canceladoMotivo: 'Cupom fiscal não impresso no totem: sem papel',
      dispositivoId: 'dev-7',
      senhaLocal: 12,
      totalCentavos: 4500,
      pagamentos: [{ forma: 'debito', valor: 4500 }],
      itens: [{ codigoPdv: 'X1', quantidade: 2 }],
    });
    // Nunca tenantId à mão: o middleware injeta.
    expect(JSON.stringify(criado)).not.toContain('tenantId');
    expect(r.pedidoId).toBe('novo');
  });

  it('pedir de novo depois de estornado → feito=true SEM chamar o Mercado Pago', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      status: 'cancelado',
    });
    prisma.pointPayment.findFirst.mockResolvedValue({
      ...POINT_APROVADO,
      status: 'refunded',
      createdAt: agora(),
    });

    const r = await service.estornarPorOrder('idem1', 'x', 'totem');

    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(r.estorno).toMatchObject({ feito: true, meio: 'debito' });
  });

  it('cancelado cujo estorno FALHOU antes → tenta de novo e registra na trilha', async () => {
    const { service, prisma, gw, auditoria } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      status: 'cancelado',
    });
    prisma.pointPayment.findFirst.mockResolvedValue({
      ...POINT_APROVADO,
      createdAt: agora(),
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'R2', status: 'approved' });

    const r = await service.estornarPorOrder('idem1', 'x', 'totem');

    expect(gw.reembolsar).toHaveBeenCalledWith('MP1', 'refund_idem1');
    expect(r.estorno).toMatchObject({ feito: true, refundId: 'R2' });
    expect(prisma.pedido.update).not.toHaveBeenCalled(); // já estava cancelado
    expect(auditoria.registrar.mock.calls.at(-1)?.[0].acao).toBe(
      'pedido.estornar',
    );
  });

  it('nenhum pagamento na nuvem (ex.: TEF no pinpad) → não estorna nem inventa registro', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);

    const r = await service.estornarPorOrder('uuid-2', 'x', 'totem');

    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.create).not.toHaveBeenCalled();
    expect(r).toMatchObject({
      pedidoId: null,
      estorno: { feito: false, meio: 'desconhecido' },
    });
  });

  it('pagamento mais velho que o prazo do totem → 422 e NADA é estornado', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pointPayment.findFirst.mockResolvedValue({
      ...POINT_APROVADO,
      createdAt: new Date(Date.now() - PRAZO_ESTORNO_TOTEM_MS - 60_000),
    });

    await expect(
      service.estornarPorOrder('uuid-3', 'x', 'totem', {
        prazoMs: PRAZO_ESTORNO_TOTEM_MS,
      }),
    ).rejects.toMatchObject({ status: 422 });
    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.create).not.toHaveBeenCalled();
  });

  it('dois estornos ao mesmo tempo (servidor da loja) → o 2º devolve o registro do 1º', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst
      .mockResolvedValueOnce(null) // ainda não existe…
      .mockResolvedValueOnce({ id: 'do-primeiro' }); // …o outro criou antes
    prisma.pointPayment.findFirst.mockResolvedValue({
      ...POINT_APROVADO,
      createdAt: agora(),
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'R1', status: 'approved' });
    prisma.pedido.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('unique', {
        code: 'P2002',
        clientVersion: 'x',
      }),
    );

    const r = await service.estornarPorOrder('uuid-4', 'x', 'totem');

    expect(r.pedidoId).toBe('do-primeiro');
  });
});

// ERR-016 — o painel estornava e o Regem seguia com a venda valendo (faturamento, estoque,
// caixa de uma venda que não existia mais).
describe('CancelamentoService.cancelarPeloPainel — o Regem desfaz antes do estorno', () => {
  beforeEach(() => vi.clearAllMocks());

  const POINT = {
    id: 'pp1',
    status: 'approved',
    paymentId: 'MP1',
    tipo: 'credito',
    amountCents: 3000,
  };

  it('Regem desfaz → estorna, cancela e mostra o que o Regem fez', async () => {
    const { service, prisma, gw, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue(POINT);
    gw.reembolsar.mockResolvedValue({ refundId: 'R1', status: 'approved' });
    regem.cancelarVendaExterna.mockResolvedValue({
      status: 'cancelada',
      encontrada: true,
      jaCancelada: false,
      notaCancelada: true,
      cancelamentoPendente: false,
    });

    const r = await service.cancelarPeloPainel('ped1', 'cliente desistiu');

    expect(regem.cancelarVendaExterna).toHaveBeenCalledWith({
      idempotencyKey: 'idem1',
      motivo: 'Cancelado no painel do GoGeM: cliente desistiu',
    });
    // A ordem importa: o Regem primeiro, o dinheiro depois.
    expect(regem.cancelarVendaExterna.mock.invocationCallOrder[0]).toBeLessThan(
      gw.reembolsar.mock.invocationCallOrder[0],
    );
    expect(r.estorno.feito).toBe(true);
    expect(r.regem).toMatchObject({ avisado: true, notaCancelada: true });
  });

  it('Regem RECUSA (nota fora do prazo) → 422 com o motivo e NADA estornado', async () => {
    const { service, prisma, gw, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue(POINT);
    regem.cancelarVendaExterna.mockRejectedValue(
      new RegemRecusouError(422, 'Prazo de cancelamento da NFC-e vencido', 'x'),
    );

    const err = await service
      .cancelarPeloPainel('ped1', 'x')
      .catch((e: unknown) => e);

    expect((err as { status: number }).status).toBe(422);
    expect(String((err as Error).message)).toContain('Prazo de cancelamento');
    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.update).not.toHaveBeenCalled();
  });

  it('Regem FORA → 503 e nada cancelado nem estornado', async () => {
    const { service, prisma, gw, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    regem.cancelarVendaExterna.mockRejectedValue(new Error('ECONNREFUSED'));

    await expect(service.cancelarPeloPainel('ped1', 'x')).rejects.toMatchObject(
      {
        status: 503,
      },
    );
    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.update).not.toHaveBeenCalled();
  });

  it('Regem sem a rota (versão antiga) → cancela e estorna aqui, e AVISA para cancelar lá', async () => {
    const { service, prisma, gw, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue(POINT);
    gw.reembolsar.mockResolvedValue({ refundId: 'R1', status: 'approved' });
    regem.cancelarVendaExterna.mockResolvedValue({ status: 'rota_ausente' });

    const r = await service.cancelarPeloPainel('ped1', 'x');

    expect(r.estorno.feito).toBe(true);
    expect(r.regem).toMatchObject({ avisado: false });
    expect(r.regem?.mensagem).toContain('cancele a venda também no Regem');
  });

  it('loja sem Regem → cancela e estorna sem aviso nenhum', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });

    const r = await service.cancelarPeloPainel('ped1', 'x');

    expect(regem.cancelarVendaExterna).toHaveBeenCalled();
    expect(r.regem).toBeUndefined();
    expect(prisma.pedido.update.mock.calls.at(-1)?.[0].data.status).toBe(
      'cancelado',
    );
  });

  it('pedido JÁ cancelado não chama o Regem de novo', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      ...PEDIDO,
      status: 'cancelado',
    });

    await service.cancelarPeloPainel('ped1', 'x');

    expect(regem.cancelarVendaExterna).not.toHaveBeenCalled();
  });
});
