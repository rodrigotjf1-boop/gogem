import { describe, expect, it, vi } from 'vitest';
import { VendasService, type DeviceCtxInfo } from './vendas.service';
import { VendaTotemDto } from './dto/venda-totem.dto';

/**
 * Fila do Point real: o totem manda 'credito' como placeholder; o backend troca
 * pela forma REAL do PointPayment (o cliente escolheu na maquininha). Cobre o bug
 * do relatório mostrar tudo como "credito".
 */
function montar(point: { status: string; tipo: string } | null) {
  const criados: any[] = [];
  let enviadoAoRegem: any = null;
  const prisma = {
    pedido: {
      findFirst: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockImplementation((args: any) => {
        criados.push(args.data);
        return Promise.resolve({ id: 'p1' });
      }),
      update: vi.fn().mockResolvedValue({}),
    },
    pointPayment: { findFirst: vi.fn().mockResolvedValue(point) },
  };
  const regem = {
    lancarVendaExterna: vi.fn().mockImplementation((body: any) => {
      enviadoAoRegem = body;
      return Promise.resolve({ comandaId: 'c1', senha: 7, total: 7.5 });
    }),
  };
  const service = new VendasService(prisma as any, regem as any);
  return {
    service,
    prisma,
    regem,
    criados,
    get enviado() {
      return enviadoAoRegem;
    },
  };
}

const CTX: DeviceCtxInfo = {
  tenantId: 't1',
  deviceId: 'd1',
  unidadeId: null,
};

function dto(forma: string): VendaTotemDto {
  return {
    idempotencyKey: 'order-1',
    itens: [{ codigoPdv: 'X1', quantidade: 1 }],
    pagamentos: [{ forma, valor: 750 }],
  } as VendaTotemDto;
}

describe('VendasService — forma real do cartão (MP Point)', () => {
  it('débito na maquininha → grava e envia "debito" (não o placeholder)', async () => {
    const h = montar({ status: 'approved', tipo: 'debito' });
    await h.service.registrarVendaTotem(CTX, dto('credito'));
    expect(h.criados[0].pagamentos[0].forma).toBe('debito');
    expect(h.enviado.pagamentos[0].forma).toBe('debito');
  });

  it('voucher → propaga "voucher"', async () => {
    const h = montar({ status: 'approved', tipo: 'voucher' });
    await h.service.registrarVendaTotem(CTX, dto('credito'));
    expect(h.criados[0].pagamentos[0].forma).toBe('voucher');
  });

  it('sem PointPayment (ex.: PIX) → mantém a forma do totem', async () => {
    const h = montar(null);
    await h.service.registrarVendaTotem(CTX, dto('pix'));
    expect(h.criados[0].pagamentos[0].forma).toBe('pix');
    expect(h.enviado.pagamentos[0].forma).toBe('pix');
  });

  it('placeholder inglês ("credit") = enriquecimento não rodou → não sobrescreve', async () => {
    const h = montar({ status: 'approved', tipo: 'credit' });
    await h.service.registrarVendaTotem(CTX, dto('credito'));
    expect(h.criados[0].pagamentos[0].forma).toBe('credito');
  });

  it('PIX não é tocado mesmo com PointPayment aprovado', async () => {
    const h = montar({ status: 'approved', tipo: 'debito' });
    await h.service.registrarVendaTotem(CTX, dto('pix'));
    expect(h.criados[0].pagamentos[0].forma).toBe('pix');
  });
});
