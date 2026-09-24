import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  mensagemDoRegem,
  RegemRecusouError,
  RegemSalesClient,
} from '../src/integracoes/regem/regem-sales.client';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';

/**
 * ERR-009 — a CLASSE do erro do Regem tem de chegar ao totem: recusa definitiva (400/422)
 * não se reenvia; queda (rede, 5xx) se reenvia. Antes tudo era `new Error` e virava 500.
 */
function cliente() {
  const resolver = {
    resolve: vi
      .fn()
      .mockResolvedValue({ base: 'https://regem/api/v1', token: 't' }),
  };
  return new RegemSalesClient(resolver as unknown as RegemConfigResolver);
}

const corpo = {
  idempotencyKey: 'k1',
  itens: [{ codigoPdv: 'X1', quantidade: 1 }],
  pagamentos: [{ forma: 'debito', valor: 10 }],
};

function responde(status: number, body: unknown) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue(
      new Response(JSON.stringify(body), {
        status,
        headers: { 'content-type': 'application/json' },
      }),
    ),
  );
}

describe('RegemSalesClient — classe do erro', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('400 do Regem → RegemRecusouError com a mensagem limpa', async () => {
    responde(400, {
      statusCode: 400,
      message: 'Código(s) PDV não encontrado(s) neste tenant: X1',
      error: 'Bad Request',
    });
    const err = await cliente()
      .lancarVendaExterna(corpo)
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(RegemRecusouError);
    expect((err as RegemRecusouError).motivo).toBe(
      'Código(s) PDV não encontrado(s) neste tenant: X1',
    );
  });

  it('422 também é recusa definitiva', async () => {
    responde(422, { message: ['campo x inválido', 'campo y inválido'] });
    const err = await cliente()
      .lancarVendaExterna(corpo)
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(RegemRecusouError);
    expect((err as RegemRecusouError).motivo).toBe(
      'campo x inválido; campo y inválido',
    );
  });

  it('503 do Regem (nota em emissão) → erro PASSAGEIRO, não recusa', async () => {
    responde(503, { message: 'A venda ainda está sendo concluída' });
    const err = await cliente()
      .lancarVendaExterna(corpo)
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(Error);
    expect(err).not.toBeInstanceOf(RegemRecusouError);
  });

  it('rede fora → erro PASSAGEIRO', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new Error('ECONNREFUSED')),
    );
    const err = await cliente()
      .lancarVendaExterna(corpo)
      .catch((e: unknown) => e);
    expect(err).not.toBeInstanceOf(RegemRecusouError);
    expect(String(err)).toContain('ECONNREFUSED');
  });

  it('dinheiro: 400 também vira recusa definitiva', async () => {
    responde(400, { message: 'Pedido sem itens.' });
    const err = await cliente()
      .lancarTotemDinheiro({ idempotencyKey: 'k1', itens: [] })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(RegemRecusouError);
  });
});

describe('mensagemDoRegem', () => {
  it('corpo que não é JSON → o próprio texto, cortado', () => {
    expect(mensagemDoRegem('Bad Gateway')).toBe('Bad Gateway');
    expect(mensagemDoRegem('')).toBe('sem detalhe');
  });
});

describe('RegemSalesClient.cancelarVendaExterna (L-FIS-3)', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('200 → cancelada, com o que o Regem fez', async () => {
    responde(200, {
      ok: true,
      notaCancelada: true,
      cancelamentoPendente: false,
    });
    const r = await cliente().cancelarVendaExterna({
      idempotencyKey: 'k1',
      motivo: 'x',
    });
    expect(r).toEqual({
      status: 'cancelada',
      encontrada: true,
      jaCancelada: false,
      notaCancelada: true,
      cancelamentoPendente: false,
    });
  });

  it('404 → rota ausente (Regem de versão antiga), sem lançar', async () => {
    responde(404, {
      message: 'Cannot POST /api/v1/vendas/externa-pdv/cancelar',
    });
    const r = await cliente().cancelarVendaExterna({
      idempotencyKey: 'k1',
      motivo: 'x',
    });
    expect(r).toEqual({ status: 'rota_ausente' });
  });

  it('422 → recusa definitiva com o motivo', async () => {
    responde(422, { message: 'Pedido já cobrado no caixa' });
    const err = await cliente()
      .cancelarVendaExterna({ idempotencyKey: 'k1', motivo: 'x' })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(RegemRecusouError);
  });

  it('empresa sem integração → sem_integracao (nada a avisar)', async () => {
    const resolver = {
      resolve: vi.fn().mockRejectedValue(new Error('sem config')),
    };
    const r = await new RegemSalesClient(
      resolver as unknown as RegemConfigResolver,
    ).cancelarVendaExterna({ idempotencyKey: 'k1', motivo: 'x' });
    expect(r).toEqual({ status: 'sem_integracao' });
  });
});
