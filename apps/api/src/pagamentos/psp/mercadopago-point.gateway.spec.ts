import { describe, expect, it } from 'vitest';
import { normalizarTipoPagamento } from './mercadopago-point.gateway';

describe('normalizarTipoPagamento (forma real do Point)', () => {
  it('mapeia os payment_type_id do MP para pt-BR', () => {
    expect(normalizarTipoPagamento('credit_card')).toBe('credito');
    expect(normalizarTipoPagamento('debit_card')).toBe('debito');
    expect(normalizarTipoPagamento('prepaid_card')).toBe('pre-pago');
    expect(normalizarTipoPagamento('voucher')).toBe('voucher');
    expect(normalizarTipoPagamento('ticket')).toBe('voucher');
    expect(normalizarTipoPagamento('account_money')).toBe('voucher');
  });

  it('é case-insensitive', () => {
    expect(normalizarTipoPagamento('CREDIT_CARD')).toBe('credito');
  });

  it('desconhecido → preserva o valor bruto (não perde informação)', () => {
    expect(normalizarTipoPagamento('bank_transfer')).toBe('bank_transfer');
  });

  it('vazio/ausente → "outro"', () => {
    expect(normalizarTipoPagamento(undefined)).toBe('outro');
    expect(normalizarTipoPagamento('')).toBe('outro');
  });
});
