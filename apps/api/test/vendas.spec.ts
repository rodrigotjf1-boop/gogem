import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { VendasService } from '../src/vendas/vendas.service';
import type { DeviceCtxInfo } from '../src/vendas/vendas.service';
import { VendaTotemDto } from '../src/vendas/dto/venda-totem.dto';
import type { RegemSalesClient } from '../src/integracoes/regem/regem-sales.client';
import type { PrismaService } from '../src/prisma/prisma.service';

const CTX: DeviceCtxInfo = {
  tenantId: 't-1',
  deviceId: 'dev-1',
  unidadeId: 'u-1',
};

function dto(overrides: Partial<VendaTotemDto> = {}): VendaTotemDto {
  return {
    idempotencyKey: 'idem-1',
    itens: [{ codigoPdv: 'PROD-1', quantidade: 2 }],
    pagamentos: [
      { forma: 'cartao', valor: 5980, nsu: '123', autorizacao: 'A9' },
    ],
    senhaLocal: 42,
    ...overrides,
  } as VendaTotemDto;
}

/** Monta o serviço com Prisma e RegemSalesClient 100% mockados (sem DB/rede). */
function makeService() {
  const prisma = {
    pedido: {
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
  };
  const regem = { lancarVendaExterna: vi.fn() };
  const service = new VendasService(
    prisma as unknown as PrismaService,
    regem as unknown as RegemSalesClient,
  );
  return { service, prisma, regem };
}

/** Junta os args de TODAS as escritas Prisma para inspeção de tenantId. */
function todasEscritas(prisma: {
  pedido: {
    create: { mock: { calls: unknown[] } };
    update: { mock: { calls: unknown[] } };
  };
}): string {
  return JSON.stringify([
    ...prisma.pedido.create.mock.calls,
    ...prisma.pedido.update.mock.calls,
  ]);
}

describe('VendasService.registrarVendaTotem — idempotência local', () => {
  beforeEach(() => vi.clearAllMocks());

  it('Pedido já ENVIADO → devolve o guardado e NÃO chama o Regem', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({
      id: 'p-1',
      status: 'enviado',
      regemComandaId: 'cmd-9',
      regemSenha: 7,
    });

    const res = await service.registrarVendaTotem(CTX, dto());

    expect(res).toEqual({ comandaId: 'cmd-9', senha: 7, idempotente: true });
    expect(regem.lancarVendaExterna).not.toHaveBeenCalled();
    expect(prisma.pedido.create).not.toHaveBeenCalled();
    expect(prisma.pedido.update).not.toHaveBeenCalled();
  });
});

describe('VendasService.registrarVendaTotem — relay de sucesso', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cria o Pedido, chama o Regem e grava enviado + comandaId/senha', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    prisma.pedido.create.mockResolvedValue({ id: 'p-1' });
    prisma.pedido.update.mockResolvedValue({});
    regem.lancarVendaExterna.mockResolvedValue({
      comandaId: 'cmd-1',
      senha: 55,
      total: 5980,
      nfce: { status: 'autorizada' },
    });

    const res = await service.registrarVendaTotem(CTX, dto());

    // Repasse com plataforma + senhaPlataforma derivada de senhaLocal.
    expect(regem.lancarVendaExterna).toHaveBeenCalledTimes(1);
    const body = regem.lancarVendaExterna.mock.calls[0][0];
    expect(body.plataforma).toBe('GoGeM Totem');
    expect(body.senhaPlataforma).toBe(42);
    expect(body.idempotencyKey).toBe('idem-1');

    // Grava enviado com o resultado do Regem.
    const updateData = prisma.pedido.update.mock.calls.at(-1)?.[0].data;
    expect(updateData.status).toBe('enviado');
    expect(updateData.regemComandaId).toBe('cmd-1');
    expect(updateData.regemSenha).toBe(55);

    expect(res).toEqual({
      comandaId: 'cmd-1',
      senha: 55,
      total: 5980,
      nfce: { status: 'autorizada' },
    });
  });

  it('grava o dispositivoId do contexto (não do body)', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    prisma.pedido.create.mockResolvedValue({ id: 'p-1' });
    prisma.pedido.update.mockResolvedValue({});
    regem.lancarVendaExterna.mockResolvedValue({
      comandaId: 'cmd-1',
      senha: 1,
    });

    await service.registrarVendaTotem(CTX, dto());

    expect(prisma.pedido.create.mock.calls[0][0].data.dispositivoId).toBe(
      'dev-1',
    );
  });
});

describe('VendasService.registrarVendaTotem — relay de falha', () => {
  beforeEach(() => vi.clearAllMocks());

  it('client lança → grava falha + erro e RELANÇA', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    prisma.pedido.create.mockResolvedValue({ id: 'p-1' });
    prisma.pedido.update.mockResolvedValue({});
    regem.lancarVendaExterna.mockRejectedValue(new Error('Regem 500'));

    await expect(service.registrarVendaTotem(CTX, dto())).rejects.toThrow(
      'Regem 500',
    );

    const updateData = prisma.pedido.update.mock.calls.at(-1)?.[0].data;
    expect(updateData.status).toBe('falha');
    expect(updateData.erro).toContain('Regem 500');
  });

  it('reabre um Pedido que falhou antes (mesma chave) em pendente', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue({ id: 'p-1', status: 'falha' });
    prisma.pedido.update.mockResolvedValue({ id: 'p-1' });
    regem.lancarVendaExterna.mockResolvedValue({
      comandaId: 'cmd-2',
      senha: 8,
    });

    const res = await service.registrarVendaTotem(CTX, dto());

    // Não recria: reabre por update (primeiro update = pendente).
    expect(prisma.pedido.create).not.toHaveBeenCalled();
    expect(prisma.pedido.update.mock.calls[0][0].data.status).toBe('pendente');
    expect(res.comandaId).toBe('cmd-2');
  });
});

describe('VendasService — sem tenantId manual (§2)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('NENHUMA escrita Prisma carrega tenantId', async () => {
    const { service, prisma, regem } = makeService();
    prisma.pedido.findFirst.mockResolvedValue(null);
    prisma.pedido.create.mockResolvedValue({ id: 'p-1' });
    prisma.pedido.update.mockResolvedValue({});
    regem.lancarVendaExterna.mockResolvedValue({
      comandaId: 'cmd-1',
      senha: 1,
    });

    await service.registrarVendaTotem(CTX, dto());

    expect(todasEscritas(prisma)).not.toContain('tenantId');
    // findFirst também não filtra por tenantId à mão (middleware injeta).
    expect(JSON.stringify(prisma.pedido.findFirst.mock.calls)).not.toContain(
      'tenantId',
    );
  });
});

describe('VendaTotemDto — validação', () => {
  it('aceita um corpo válido', async () => {
    const instance = plainToInstance(VendaTotemDto, dto());
    expect(await validate(instance)).toHaveLength(0);
  });

  it('rejeita itens vazios', async () => {
    const instance = plainToInstance(VendaTotemDto, dto({ itens: [] }));
    const errs = await validate(instance);
    expect(errs.some((e) => e.property === 'itens')).toBe(true);
  });

  it('rejeita pagamentos vazios', async () => {
    const instance = plainToInstance(VendaTotemDto, dto({ pagamentos: [] }));
    const errs = await validate(instance);
    expect(errs.some((e) => e.property === 'pagamentos')).toBe(true);
  });

  it('rejeita idempotencyKey ausente', async () => {
    const bad = dto();
    delete (bad as { idempotencyKey?: string }).idempotencyKey;
    const errs = await validate(plainToInstance(VendaTotemDto, bad));
    expect(errs.some((e) => e.property === 'idempotencyKey')).toBe(true);
  });
});
