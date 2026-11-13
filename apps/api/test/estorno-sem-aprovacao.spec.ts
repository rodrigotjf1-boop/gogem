import 'reflect-metadata';
import {
  BadRequestException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { describe, expect, it, vi } from 'vitest';
import { CancelarTotemDto } from '../src/integracoes/regem/dto/cancelar-totem.dto';
import {
  conferirQuemCancelou,
  MSG_ESTORNO_SO_DE_PESSOA,
} from '../src/integracoes/regem/estorno-sem-aprovacao';
import { RegemInboundService } from '../src/integracoes/regem/regem-inbound.service';

// A exceção do estorno (Padrão DMS, F5-10): sem aprovação no GoGeM, só sai o estorno de um cancelamento feito por
// uma PESSOA no Regem. Sem o campo, o Regem de antes desta versão segue funcionando.

describe('conferirQuemCancelou (a regra pura)', () => {
  it('pessoa e ausente podem estornar', () => {
    expect(conferirQuemCancelou('pessoa')).toBeNull();
    expect(conferirQuemCancelou(undefined)).toBeNull();
    expect(conferirQuemCancelou(null)).toBeNull();
  });

  it('agente é recusado com a frase do pacote comum', () => {
    expect(conferirQuemCancelou('agente')).toEqual({
      tipo: 'regra-invalida',
      mensagem: MSG_ESTORNO_SO_DE_PESSOA,
    });
  });

  it('outro valor é parâmetro inválido (nem "Pessoa", nem número)', () => {
    for (const v of ['Pessoa', 'robo', '', 1, true, {}]) {
      expect(conferirQuemCancelou(v)?.tipo).toBe('parametro-invalido');
    }
  });
});

describe('CancelarTotemDto (a rota do X-Sync-Token, com whitelist e forbidNonWhitelisted)', () => {
  const opcoes = { whitelist: true, forbidNonWhitelisted: true };

  it('aceita canceladoPor "pessoa" e "agente" (a recusa do agente é da regra, não do DTO)', async () => {
    for (const canceladoPor of ['pessoa', 'agente']) {
      const dto = plainToInstance(CancelarTotemDto, {
        idempotencyKey: 'totem-1',
        motivo: 'Desistiu',
        canceladoPor,
      });
      expect(await validate(dto, opcoes)).toHaveLength(0);
    }
  });

  it('sem o campo continua válido (o Regem de antes desta versão)', async () => {
    const dto = plainToInstance(CancelarTotemDto, {
      idempotencyKey: 'totem-1',
    });
    expect(await validate(dto, opcoes)).toHaveLength(0);
  });

  it('valor fora da lista é recusado na borda (400)', async () => {
    const dto = plainToInstance(CancelarTotemDto, {
      idempotencyKey: 'totem-1',
      canceladoPor: 'robo',
    });
    const erros = await validate(dto, opcoes);
    expect(erros.map((e) => e.property)).toEqual(['canceladoPor']);
  });
});

describe('as duas entradas do cancelamento do Regem', () => {
  const resultado = {
    status: 'cancelado' as const,
    pedidoId: 'p1',
    estorno: {
      feito: true,
      meio: 'pix',
      valorCentavos: 1000,
      refundId: 'r1',
      mensagem: 'ok',
    },
  };

  function inbound() {
    const cancelamento = {
      cancelarPorChave: vi.fn().mockResolvedValue(resultado),
    };
    const s = new RegemInboundService(
      {} as never,
      {} as never,
      {} as never,
      cancelamento as never,
    );
    // O token é conferido no banco; aqui só importa a regra que vem depois dele.
    const tenantPorToken = vi
      .spyOn(s as never, 'tenantPorToken' as never)
      .mockResolvedValue('t1' as never);
    return { s, cancelamento, tenantPorToken };
  }
  const aviso = (pedido: Record<string, unknown>) => ({
    tenantId: 't1',
    corpo: { tipo: 'pedido.cancelado', contrato: 1, loja_id: 'x', pedido },
  });

  it('X-Sync-Token: "pessoa" estorna como sempre', async () => {
    const { s, cancelamento } = inbound();
    await expect(
      s.cancelarPedido('tok', {
        idempotencyKey: 'totem-1',
        motivo: 'Desistiu',
        canceladoPor: 'pessoa',
      }),
    ).resolves.toEqual(resultado);
    expect(cancelamento.cancelarPorChave).toHaveBeenCalledWith(
      { idempotencyKey: 'totem-1', regemComandaId: undefined },
      'Desistiu',
      'regem',
    );
  });

  it('X-Sync-Token: sem o campo estorna como antes (transição)', async () => {
    const { s, cancelamento } = inbound();
    await expect(
      s.cancelarPedido('tok', { idempotencyKey: 'totem-1' }),
    ).resolves.toEqual(resultado);
    expect(cancelamento.cancelarPorChave).toHaveBeenCalledTimes(1);
  });

  it('X-Sync-Token: "agente" → 422 regra-invalida, e nada é cancelado nem estornado', async () => {
    const { s, cancelamento, tenantPorToken } = inbound();
    const erro = await s
      .cancelarPedido('tok', {
        idempotencyKey: 'totem-1',
        canceladoPor: 'agente',
      })
      .catch((e: unknown) => e);
    expect(erro).toBeInstanceOf(UnprocessableEntityException);
    expect((erro as UnprocessableEntityException).getResponse()).toEqual({
      code: 'regra-invalida',
      message: MSG_ESTORNO_SO_DE_PESSOA,
    });
    // O token vem antes: quem não se identificou não chega à regra.
    expect(tenantPorToken).toHaveBeenCalledWith('tok');
    expect(cancelamento.cancelarPorChave).not.toHaveBeenCalled();
  });

  it('X-Sync-Token: token recusado responde pelo token, antes da regra', async () => {
    const { s, cancelamento, tenantPorToken } = inbound();
    tenantPorToken.mockRejectedValueOnce(new Error('token inválido') as never);
    await expect(
      s.cancelarPedido('ruim', {
        idempotencyKey: 'totem-1',
        canceladoPor: 'agente',
      }),
    ).rejects.toThrow('token inválido');
    expect(cancelamento.cancelarPorChave).not.toHaveBeenCalled();
  });

  it('aviso assinado: "pessoa" e sem o campo estornam', async () => {
    const { s, cancelamento } = inbound();
    await expect(
      s.tratarAviso(
        aviso({ idempotencyKey: 'totem-1', canceladoPor: 'pessoa' }),
      ),
    ).resolves.toEqual(resultado);
    await expect(
      s.tratarAviso(aviso({ idempotencyKey: 'totem-2' })),
    ).resolves.toEqual(resultado);
    expect(cancelamento.cancelarPorChave).toHaveBeenCalledTimes(2);
  });

  it('aviso assinado: "agente" → 422 regra-invalida, sem cancelar', async () => {
    const { s, cancelamento } = inbound();
    const erro = await s
      .tratarAviso(aviso({ idempotencyKey: 'totem-1', canceladoPor: 'agente' }))
      .catch((e: unknown) => e);
    expect(erro).toBeInstanceOf(UnprocessableEntityException);
    expect(
      ((erro as UnprocessableEntityException).getResponse() as { code: string })
        .code,
    ).toBe('regra-invalida');
    expect(cancelamento.cancelarPorChave).not.toHaveBeenCalled();
  });

  it('aviso assinado: valor fora da lista → 400 (o aviso não tem DTO; a regra confere)', async () => {
    const { s, cancelamento } = inbound();
    await expect(
      s.tratarAviso(aviso({ idempotencyKey: 'totem-1', canceladoPor: 'robo' })),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(cancelamento.cancelarPorChave).not.toHaveBeenCalled();
  });
});
