import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RelatorioService } from '../src/relatorio/relatorio.service';
import type { PrismaService } from '../src/prisma/prisma.service';

function makeService() {
  const prisma = {
    pedido: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      aggregate: vi.fn(),
    },
    dispositivo: { findMany: vi.fn() },
    produto: { findMany: vi.fn() },
  };
  const cancelamento = { cancelarPorId: vi.fn() };
  const service = new RelatorioService(
    prisma as unknown as PrismaService,
    cancelamento as unknown as import('../src/pagamentos/cancelamento.service').CancelamentoService,
  );
  return { service, prisma, cancelamento };
}

describe('RelatorioService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('pedidos resolve o nome do dispositivo e extrai as formas de pagamento', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findMany.mockResolvedValue([
      {
        id: 'p1',
        createdAt: new Date('2026-07-10T12:00:00Z'),
        dispositivoId: 'd1',
        cliente: 'Ana',
        cpf: null,
        consumo: 'viagem',
        senhaLocal: 7,
        status: 'enviado',
        totalCentavos: 2990,
        pagamentos: [{ forma: 'cartao', valor: 2990 }],
        itens: [{ codigoPdv: 'X', quantidade: 1 }],
        canceladoMotivo: null,
      },
    ]);
    prisma.dispositivo.findMany.mockResolvedValue([
      { id: 'd1', nome: 'Totem 1' },
    ]);

    const out = await service.pedidos(
      new Date('2026-07-01'),
      new Date('2026-07-31'),
    );
    expect(out).toHaveLength(1);
    expect(out[0].dispositivo).toBe('Totem 1');
    expect(out[0].formas).toEqual(['cartao']);
    expect(out[0].itens).toBe(1);
    expect(out[0].consumo).toBe('viagem');
  });

  it('faturamento soma só o total e calcula o ticket médio', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.aggregate.mockResolvedValue({
      _sum: { totalCentavos: 6000 },
      _count: 2,
    });
    const card = await service.faturamento(new Date('2026-07-01'), new Date());
    expect(card).toEqual({
      totalCentavos: 6000,
      pedidos: 2,
      ticketMedioCentavos: 3000,
    });
    // Faturamento conta apenas pedidos 'enviado'.
    expect(prisma.pedido.aggregate.mock.calls[0][0].where.status).toBe(
      'enviado',
    );
  });

  it('porProduto agrega quantidade por codigoPdv e resolve o nome pelo de-para regem', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findMany.mockResolvedValue([
      {
        itens: [
          { codigoPdv: 'A', quantidade: 2 },
          { codigoPdv: 'B', quantidade: 1 },
        ],
      },
      { itens: [{ codigoPdv: 'A', quantidade: 3 }] },
    ]);
    prisma.produto.findMany.mockResolvedValue([
      {
        nome: 'X-Burger',
        externalRefs: [{ sistema: 'regem', codigo_pdv: 'A' }],
      },
    ]);
    const ranking = await service.porProduto(
      new Date('2026-07-01'),
      new Date(),
    );
    expect(ranking[0]).toEqual({
      codigoPdv: 'A',
      nome: 'X-Burger',
      quantidade: 5,
      pedidos: 2,
    });
    // Sem produto casado → cai para o próprio código.
    expect(ranking[1]).toEqual({
      codigoPdv: 'B',
      nome: 'B',
      quantidade: 1,
      pedidos: 1,
    });
  });

  it('cancelar delega ao CancelamentoService (origem admin) e devolve o estorno', async () => {
    const { service, cancelamento } = makeService();
    cancelamento.cancelarPorId.mockResolvedValue({
      status: 'cancelado',
      pedidoId: 'p1',
      estorno: { feito: true, meio: 'credito', valorCentavos: 3000 },
    });
    const res = await service.cancelar('p1', 'falta de saldo');
    expect(cancelamento.cancelarPorId).toHaveBeenCalledWith(
      'p1',
      'falta de saldo',
      'admin',
    );
    expect(res.status).toBe('cancelado');
    expect(res.estorno.feito).toBe(true);
  });

  it('porPagamento agrupa por forma·bandeira e soma os valores', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findMany.mockResolvedValue([
      {
        totalCentavos: 3000,
        pagamentos: [{ forma: 'credito', bandeira: 'visa', valor: 3000 }],
      },
      {
        totalCentavos: 1000,
        pagamentos: [{ forma: 'credito', bandeira: 'visa', valor: 1000 }],
      },
      {
        totalCentavos: 500,
        pagamentos: [{ forma: 'pix', valor: 500 }],
      },
      {
        // sem `valor` → rateia o total entre as formas (aqui, 1 forma = total)
        totalCentavos: 800,
        pagamentos: [{ forma: 'dinheiro' }],
      },
    ]);

    const out = await service.porPagamento(new Date(0), new Date());
    // Ordenado por total desc.
    expect(out[0]).toEqual({
      forma: 'credito',
      bandeira: 'visa',
      pedidos: 2,
      totalCentavos: 4000,
    });
    const pix = out.find((r) => r.forma === 'pix');
    expect(pix).toEqual({
      forma: 'pix',
      bandeira: null,
      pedidos: 1,
      totalCentavos: 500,
    });
    const din = out.find((r) => r.forma === 'dinheiro');
    expect(din?.totalCentavos).toBe(800); // rateio do total sem `valor`
  });

  it('porHorario devolve 24 horas e agrupa no fuso America/Sao_Paulo', async () => {
    const { service, prisma } = makeService();
    // 23:30 UTC = 20:30 em São Paulo (UTC-3).
    prisma.pedido.findMany.mockResolvedValue([
      { createdAt: new Date('2026-07-10T23:30:00Z'), totalCentavos: 1000 },
      { createdAt: new Date('2026-07-10T23:45:00Z'), totalCentavos: 2000 },
    ]);

    const out = await service.porHorario(new Date(0), new Date());
    expect(out).toHaveLength(24);
    expect(out[20]).toEqual({ hora: 20, pedidos: 2, totalCentavos: 3000 });
    expect(out[23].pedidos).toBe(0); // 23h UTC não vira 23h local
  });
});
