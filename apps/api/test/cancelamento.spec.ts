import { NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  CancelamentoService,
  PRAZO_ESTORNO_TOTEM_MS,
} from '../src/pagamentos/cancelamento.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import type { PspResolver } from '../src/pagamentos/psp/psp-resolver';
import type { AuditoriaService } from '../src/auditoria/auditoria.service';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';

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
  // Loja SEM Regem por padrão (o resolver não acha configuração).
  const regem = {
    resolve: vi.fn().mockRejectedValue(new Error('sem integração')),
  };
  const service = new CancelamentoService(
    prisma as unknown as PrismaService,
    psp as unknown as PspResolver,
    auditoria as unknown as AuditoriaService,
    regem as unknown as RegemConfigResolver,
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

// ERR-016 — decisão do dono (25/09/2026): com o Regem ATIVO, cancela-se no Regem. O painel
// estornava e o Regem seguia com a venda valendo.
describe('CancelamentoService — cancelamento pelo painel', () => {
  beforeEach(() => vi.clearAllMocks());

  it('loja INTEGRADA ao Regem → 409 com o porquê, e NADA estornado nem cancelado', async () => {
    const { service, prisma, gw, regem } = makeService();
    regem.resolve.mockResolvedValue({ base: 'https://regem', token: 't' });
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue({
      id: 'pp1',
      status: 'approved',
      paymentId: 'MP1',
      tipo: 'credito',
      amountCents: 3000,
    });

    const err = await service
      .cancelarPeloPainel('ped1', 'x')
      .catch((e: unknown) => e);

    expect((err as { status: number }).status).toBe(409);
    expect(String((err as Error).message)).toContain(
      'o cancelamento é feito no Regem',
    );
    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.update).not.toHaveBeenCalled();
  });

  it('loja SEM Regem → cancela e estorna pelo painel, como sempre', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });
    prisma.pointPayment.findFirst.mockResolvedValue({
      id: 'pp1',
      status: 'approved',
      paymentId: 'MP1',
      tipo: 'credito',
      amountCents: 3000,
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'R1', status: 'approved' });

    const r = await service.cancelarPeloPainel('ped1', 'cliente desistiu');

    expect(r.estorno.feito).toBe(true);
    expect(prisma.pedido.update.mock.calls.at(-1)?.[0].data.status).toBe(
      'cancelado',
    );
  });

  it('regraCancelamento diz à tela se o painel pode cancelar', async () => {
    const semRegem = makeService();
    expect(await semRegem.service.regraCancelamento()).toEqual({
      noPainel: true,
      mensagem: null,
    });
    const comRegem = makeService();
    comRegem.regem.resolve.mockResolvedValue({ base: 'b', token: 't' });
    expect(await comRegem.service.regraCancelamento()).toMatchObject({
      noPainel: false,
    });
  });
});

// ERR-026 — no servidor da loja a nuvem não tem o pedido, só o pagamento: o cancelamento
// feito no Regem respondia 404 e o cartão não era estornado.
describe('CancelamentoService.cancelarPorChave — cancelamento vindo do Regem', () => {
  beforeEach(() => vi.clearAllMocks());

  it('servidor da loja (sem pedido na nuvem) → estorna pelo pagamento e registra', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    prisma.pointPayment.findFirst.mockResolvedValue({
      id: 'pp9',
      status: 'approved',
      paymentId: 'MP9',
      tipo: 'debito',
      amountCents: 4200,
      createdAt: new Date(),
    });
    gw.reembolsar.mockResolvedValue({ refundId: 'R9', status: 'approved' });

    const r = await service.cancelarPorChave(
      { idempotencyKey: 'uuid-9' },
      'Cancelado no Regem: cliente desistiu',
      'regem',
    );

    expect(gw.reembolsar).toHaveBeenCalledWith('MP9', 'refund_uuid-9');
    expect(r).toMatchObject({
      status: 'cancelado',
      pedidoId: 'novo',
      estorno: { feito: true, refundId: 'R9' },
    });
    expect(prisma.pedido.create.mock.calls[0][0].data).toMatchObject({
      idempotencyKey: 'uuid-9',
      status: 'cancelado',
      canceladoMotivo: 'Cancelado no Regem: cliente desistiu',
      totalCentavos: 4200,
    });
  });

  it('sem pagamento eletrônico na nuvem → 200 com feito=false, sem inventar registro', async () => {
    const { service, prisma, gw } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);

    const r = await service.cancelarPorChave(
      { idempotencyKey: 'uuid-din' },
      'x',
      'regem',
    );

    expect(gw.reembolsar).not.toHaveBeenCalled();
    expect(prisma.pedido.create).not.toHaveBeenCalled();
    expect(r).toMatchObject({ pedidoId: null, estorno: { feito: false } });
  });

  it('só a comanda do Regem, sem pedido na nuvem → 404 (sem a chave não há como achar o pagamento)', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);

    await expect(
      service.cancelarPorChave({ regemComandaId: 'cmd-1' }, 'x', 'regem'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('cancelamento vindo do Regem NÃO passa pela regra do painel (é o caminho certo)', async () => {
    const { service, prisma, regem } = makeService();
    regem.resolve.mockResolvedValue({ base: 'b', token: 't' });
    prisma.pedido.findFirst.mockResolvedValue({ ...PEDIDO });

    const r = await service.cancelarPorChave(
      { idempotencyKey: 'idem1' },
      'x',
      'regem',
    );

    expect(r.status).toBe('cancelado');
  });
});
