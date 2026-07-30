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
  const service = new RelatorioService(prisma as unknown as PrismaService);
  return { service, prisma };
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

  it('cancelar marca cancelado com motivo e timestamp', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ id: 'p1', status: 'enviado' });
    prisma.pedido.update.mockResolvedValue({ id: 'p1' });
    const agora = new Date('2026-07-29T10:00:00Z');
    await service.cancelar('p1', 'falta de saldo', agora);
    const data = prisma.pedido.update.mock.calls[0][0].data;
    expect(data.status).toBe('cancelado');
    expect(data.canceladoMotivo).toBe('falta de saldo');
    expect(data.canceladoEm).toBe(agora);
  });

  it('cancelar recusa pedido já cancelado', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      id: 'p1',
      status: 'cancelado',
    });
    await expect(service.cancelar('p1', 'x', new Date())).rejects.toThrow();
    expect(prisma.pedido.update).not.toHaveBeenCalled();
  });

  it('cancelar recusa pedido inexistente', async () => {
    const { service, prisma } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    await expect(service.cancelar('nope', 'x', new Date())).rejects.toThrow();
  });
});
