import 'reflect-metadata';
import { RequestMethod } from '@nestjs/common';
import {
  GUARDS_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { describe, expect, it } from 'vitest';
import { DeviceTokenGuard } from '../src/auth/device-token.guard';
import { EstornoTotemDto } from '../src/pagamentos/dto/estorno-totem.dto';
import { PagamentosController } from '../src/pagamentos/pagamentos.controller';

/**
 * Rota de estorno do totem — o CONTRATO com o Regem (#574): o servidor da loja repassa
 * exatamente `pagamentos/estorno` para a nuvem do GoGeM. Mudar o caminho quebra o
 * estorno em toda loja com servidor local, calado.
 */
describe('POST /pagamentos/estorno — contrato', () => {
  const handler = PagamentosController.prototype.estornar;

  it('existe em pagamentos/estorno, é POST e exige o token do aparelho', () => {
    expect(Reflect.getMetadata(PATH_METADATA, PagamentosController)).toBe(
      'pagamentos',
    );
    expect(Reflect.getMetadata(PATH_METADATA, handler)).toBe('estorno');
    expect(Reflect.getMetadata(METHOD_METADATA, handler)).toBe(
      RequestMethod.POST,
    );
    expect(Reflect.getMetadata(GUARDS_METADATA, handler)).toContain(
      DeviceTokenGuard,
    );
  });
});

describe('EstornoTotemDto — validação', () => {
  const valido = {
    orderId: '9b1c0f7e-0000-4000-8000-000000000001',
    motivo: 'NFC-e não emitida (rejeitada 778): NCM inexistente',
    etapa: 'rejeitada',
  };

  it('aceita o corpo mínimo do totem', async () => {
    expect(
      await validate(plainToInstance(EstornoTotemDto, valido)),
    ).toHaveLength(0);
  });

  it('aceita senha e itens (registro do servidor da loja)', async () => {
    const dto = plainToInstance(EstornoTotemDto, {
      ...valido,
      senha: 12,
      itens: [{ codigoPdv: 'X1', quantidade: 2 }],
    });
    expect(await validate(dto)).toHaveLength(0);
  });

  it('recusa sem orderId ou sem motivo', async () => {
    const semOrder = await validate(
      plainToInstance(EstornoTotemDto, { motivo: 'x' }),
    );
    expect(semOrder.some((e) => e.property === 'orderId')).toBe(true);
    const semMotivo = await validate(
      plainToInstance(EstornoTotemDto, { orderId: 'o1' }),
    );
    expect(semMotivo.some((e) => e.property === 'motivo')).toBe(true);
  });

  it('recusa item inválido (quantidade zero)', async () => {
    const errs = await validate(
      plainToInstance(EstornoTotemDto, {
        ...valido,
        itens: [{ codigoPdv: 'X1', quantidade: 0 }],
      }),
    );
    expect(errs.some((e) => e.property === 'itens')).toBe(true);
  });
});
