import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createHmac } from 'node:crypto';
import { UnauthorizedException } from '@nestjs/common';
import {
  avisoAutentico,
  dataIdDaQuery,
  lerXSignature,
  manifestoDoAviso,
} from '../src/pagamentos/psp/assinatura-mp';
import { PspResolver } from '../src/pagamentos/psp/psp-resolver';
import { PagamentosService } from '../src/pagamentos/pagamentos.service';
import { PointService } from '../src/pagamentos/point.service';
import {
  ENV_CHAVE_DOS_SEGREDOS,
  contextoDoSegredo,
} from '../src/integracao/segredos';
import { cifrar } from '../src/common/cifra';
import type { PrismaService } from '../src/prisma/prisma.service';

// Valores de teste de baixa entropia: só valem aqui.
const SEGREDO = 'assinatura-de-teste';
const CHAVE = Buffer.alloc(32, 7);

/** O que o Mercado Pago mandaria: HMAC-SHA256 hex do texto, com o segredo. */
const assinar = (texto: string, segredo = SEGREDO) =>
  createHmac('sha256', segredo).update(texto).digest('hex');

describe('assinatura dos avisos do Mercado Pago — formato da documentação', () => {
  it('monta o texto assinado no formato id;request-id;ts;', () => {
    expect(manifestoDoAviso('123456', 'req-1', '1704908010')).toBe(
      'id:123456;request-id:req-1;ts:1704908010;',
    );
  });

  it('id alfanumérico vai em minúsculas', () => {
    expect(manifestoDoAviso('ORD01ABC', 'req-1', '1')).toBe(
      'id:ord01abc;request-id:req-1;ts:1;',
    );
  });

  it('o que não veio sai do texto', () => {
    expect(manifestoDoAviso('9', undefined, '1')).toBe('id:9;ts:1;');
    expect(manifestoDoAviso(null, 'req-1', '1')).toBe('request-id:req-1;ts:1;');
  });

  it('lê ts e v1 do cabeçalho, em qualquer ordem e com espaços', () => {
    expect(lerXSignature('ts=1,v1=abc')).toEqual({ ts: '1', v1: 'abc' });
    expect(lerXSignature(' v1=abc , ts=1 ')).toEqual({ ts: '1', v1: 'abc' });
    expect(lerXSignature('ts=1')).toBeNull();
    expect(lerXSignature(undefined)).toBeNull();
  });

  it('data.id vem da query (o que o Mercado Pago assinou)', () => {
    expect(dataIdDaQuery({ 'data.id': '123' })).toBe('123');
    expect(dataIdDaQuery({ 'data.id': ['123', '9'] })).toBe('123');
    expect(dataIdDaQuery({})).toBeNull();
    expect(dataIdDaQuery({ 'data.id': '' })).toBeNull();
  });

  it('aceita a assinatura certa (também em hexadecimal maiúsculo)', () => {
    const v1 = assinar('id:123;request-id:req-1;ts:1704908010;');
    const base = { xRequestId: 'req-1', dataId: '123', segredo: SEGREDO };
    expect(
      avisoAutentico({ ...base, xSignature: `ts=1704908010,v1=${v1}` }),
    ).toBe(true);
    expect(
      avisoAutentico({
        ...base,
        xSignature: `ts=1704908010,v1=${v1.toUpperCase()}`,
      }),
    ).toBe(true);
  });

  it('recusa: outro segredo, outro id, outro instante, sem cabeçalho ou sem segredo', () => {
    const v1 = assinar('id:123;request-id:req-1;ts:1704908010;');
    const ok = {
      xSignature: `ts=1704908010,v1=${v1}`,
      xRequestId: 'req-1',
      dataId: '123',
      segredo: SEGREDO,
    };
    expect(avisoAutentico({ ...ok, segredo: 'outro-segredo' })).toBe(false);
    expect(avisoAutentico({ ...ok, dataId: '124' })).toBe(false);
    expect(
      avisoAutentico({ ...ok, xSignature: `ts=1704908011,v1=${v1}` }),
    ).toBe(false);
    expect(avisoAutentico({ ...ok, xSignature: undefined })).toBe(false);
    expect(avisoAutentico({ ...ok, xSignature: 'ts=1,v1=curta' })).toBe(false);
    expect(avisoAutentico({ ...ok, segredo: '' })).toBe(false);
  });
});

/** Banco simulado com a cobrança PIX, o pagamento Point e a integração MP. */
function makeBanco(configMp: Record<string, unknown> | null) {
  return {
    pixCharge: {
      findFirst: vi.fn().mockResolvedValue({
        id: 'c1',
        tenantId: 't1',
        orderId: 'o1',
        pspRef: '123',
        status: 'pending',
        expiresAt: null,
      }),
      update: vi.fn().mockResolvedValue({}),
    },
    pointPayment: {
      findFirst: vi.fn().mockResolvedValue({
        id: 'p1',
        tenantId: 't1',
        orderId: 'o1',
        deviceId: 'POINT-1',
        intentId: 'int-abc',
        status: 'pending',
        tipo: 'credit',
        bandeira: null,
        paymentId: null,
      }),
      update: vi.fn().mockResolvedValue({}),
    },
    pointJournal: { create: vi.fn().mockResolvedValue({}) },
    integracao: {
      findFirst: vi.fn().mockResolvedValue(
        configMp && {
          tenantId: 't1',
          unidadeId: null,
          tipo: 'mercadopago',
          ativo: true,
          config: configMp,
        },
      ),
    },
  };
}

describe('webhook do PIX (/pagamentos/pix/webhook) confere a assinatura', () => {
  beforeEach(() => {
    process.env[ENV_CHAVE_DOS_SEGREDOS] = CHAVE.toString('base64');
  });
  afterEach(() => {
    delete process.env[ENV_CHAVE_DOS_SEGREDOS];
    vi.restoreAllMocks();
  });

  function make(configMp: Record<string, unknown> | null) {
    const prisma = makeBanco(configMp);
    const resolver = new PspResolver(prisma as unknown as PrismaService);
    const psp = { consultar: vi.fn().mockResolvedValue('approved') };
    vi.spyOn(resolver, 'resolver').mockResolvedValue(psp as any);
    const service = new PagamentosService(
      prisma as unknown as PrismaService,
      resolver,
    );
    return { service, prisma, psp };
  }

  const segredoCifrado = () =>
    cifrar(
      SEGREDO,
      CHAVE,
      contextoDoSegredo(
        { tenantId: 't1', unidadeId: null, tipo: 'mercadopago' },
        'segredoDosAvisos',
      ),
    );
  const corpo = { type: 'payment', data: { id: '123' } };
  const query = { 'data.id': '123', type: 'payment' };
  const assinado = {
    xSignature: `ts=1704908010,v1=${assinar('id:123;request-id:req-1;ts:1704908010;')}`,
    xRequestId: 'req-1',
  };

  it('assinatura certa → reconsulta o Mercado Pago como hoje', async () => {
    const { service, psp, prisma } = make({
      accessToken: 'mp-de-teste',
      segredoDosAvisos: segredoCifrado(),
    });
    await expect(service.webhook(corpo, query, assinado)).resolves.toEqual({
      ok: true,
    });
    expect(psp.consultar).toHaveBeenCalledWith('123');
    expect(prisma.pixCharge.update).toHaveBeenCalled();
  });

  it('assinatura errada → 401, sem consultar o Mercado Pago', async () => {
    const { service, psp } = make({
      accessToken: 'mp-de-teste',
      segredoDosAvisos: segredoCifrado(),
    });
    await expect(
      service.webhook(corpo, query, {
        ...assinado,
        xSignature: `ts=1704908010,v1=${assinar('id:123;request-id:req-1;ts:1704908010;', 'outro')}`,
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(psp.consultar).not.toHaveBeenCalled();
  });

  it('aviso sem assinatura → 401', async () => {
    const { service, psp } = make({
      accessToken: 'mp-de-teste',
      segredoDosAvisos: segredoCifrado(),
    });
    await expect(service.webhook(corpo, query, {})).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(psp.consultar).not.toHaveBeenCalled();
  });

  it('loja sem a assinatura secreta configurada → 401', async () => {
    const { service, psp } = make({ accessToken: 'mp-de-teste' });
    await expect(
      service.webhook(corpo, query, assinado),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(psp.consultar).not.toHaveBeenCalled();
  });

  it('id assinado diferente do id do corpo → 401', async () => {
    const { service, psp } = make({
      accessToken: 'mp-de-teste',
      segredoDosAvisos: segredoCifrado(),
    });
    await expect(
      service.webhook(
        { type: 'payment', data: { id: '123' } },
        { 'data.id': '999' },
        {
          xSignature: `ts=1,v1=${assinar('id:999;request-id:req-1;ts:1;')}`,
          xRequestId: 'req-1',
        },
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(psp.consultar).not.toHaveBeenCalled();
  });

  it('pagamento desconhecido → 200 sem consultar nada (como hoje)', async () => {
    const { service, psp, prisma } = make({ accessToken: 'mp-de-teste' });
    prisma.pixCharge.findFirst.mockResolvedValue(null);
    await expect(service.webhook(corpo, query, {})).resolves.toEqual({
      ok: true,
    });
    expect(psp.consultar).not.toHaveBeenCalled();
    expect(prisma.integracao.findFirst).not.toHaveBeenCalled();
  });
});

describe('webhook do Point (/pagamentos/point/webhook) confere a assinatura', () => {
  afterEach(() => vi.restoreAllMocks());

  function make(configMp: Record<string, unknown> | null) {
    const prisma = makeBanco(configMp);
    const resolver = new PspResolver(prisma as unknown as PrismaService);
    const gw = {
      consultar: vi.fn().mockResolvedValue({ status: 'pending' }),
    };
    vi.spyOn(resolver, 'resolverPoint').mockResolvedValue(gw as any);
    const service = new PointService(
      prisma as unknown as PrismaService,
      resolver,
    );
    return { service, gw };
  }

  const corpo = { topic: 'point_integration_wh', id: 'int-abc' };

  it('assinatura certa (aviso sem data.id na query) → reconsulta', async () => {
    // Segredo legado em claro: lido como está (antes da migração do boot).
    const { service, gw } = make({
      accessToken: 'mp',
      segredoDosAvisos: SEGREDO,
    });
    await service.webhook(
      corpo,
      {},
      {
        xSignature: `ts=1,v1=${assinar('request-id:req-1;ts:1;')}`,
        xRequestId: 'req-1',
      },
    );
    expect(gw.consultar).toHaveBeenCalledWith('int-abc');
  });

  it('assinatura errada → 401, sem consultar o Mercado Pago', async () => {
    const { service, gw } = make({
      accessToken: 'mp',
      segredoDosAvisos: SEGREDO,
    });
    await expect(
      service.webhook(corpo, {}, { xSignature: 'ts=1,v1=00', xRequestId: 'r' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(gw.consultar).not.toHaveBeenCalled();
  });
});
