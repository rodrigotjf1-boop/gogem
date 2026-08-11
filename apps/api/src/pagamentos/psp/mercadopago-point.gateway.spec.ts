import { describe, expect, it } from 'vitest';
import {
  classificarPagamento,
  ehBandeiraVoucher,
  normalizarTipoPagamento,
} from './mercadopago-point.gateway';

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

describe('ehBandeiraVoucher', () => {
  it('reconhece marcas de vale-refeição', () => {
    expect(ehBandeiraVoucher('alelo')).toBe(true);
    expect(ehBandeiraVoucher('sodexo')).toBe(true);
    expect(ehBandeiraVoucher('vr')).toBe(true);
    expect(ehBandeiraVoucher('ticket_refeicao')).toBe(true);
    expect(ehBandeiraVoucher('valecard')).toBe(true);
  });

  it('não confunde bandeiras de cartão comum', () => {
    expect(ehBandeiraVoucher('visa')).toBe(false);
    expect(ehBandeiraVoucher('master')).toBe(false);
    expect(ehBandeiraVoucher('elo')).toBe(false);
    expect(ehBandeiraVoucher(undefined)).toBe(false);
    expect(ehBandeiraVoucher('')).toBe(false);
  });
});

describe('classificarPagamento (tipo + bandeira)', () => {
  it('cartão de crédito Visa', () => {
    expect(classificarPagamento('credit_card', 'visa')).toEqual({
      tipo: 'credito',
      bandeira: 'visa',
    });
  });

  it('débito Master', () => {
    expect(classificarPagamento('debit_card', 'master')).toEqual({
      tipo: 'debito',
      bandeira: 'master',
    });
  });

  it('VR que vem como debit_card → reclassifica pra voucher', () => {
    expect(classificarPagamento('debit_card', 'alelo')).toEqual({
      tipo: 'voucher',
      bandeira: 'alelo',
    });
  });

  it('sem payment_method_id → bandeira null', () => {
    expect(classificarPagamento('credit_card', undefined)).toEqual({
      tipo: 'credito',
      bandeira: null,
    });
  });
});
