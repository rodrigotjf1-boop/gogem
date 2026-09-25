import { describe, expect, it } from 'vitest';
import {
  fimDaLoja,
  inicioDaLoja,
  inicioDoDia,
  inicioDoMes,
  paredeEm,
} from '../src/common/fuso-loja';
import { periodo } from '../src/relatorio/periodo';

/**
 * ERR-014 — com a API e o banco em UTC (produção: `show timezone` = Etc/UTC), o dia virava às
 * 21h de Brasília. Estes testes não dependem do fuso da máquina que roda: tudo é calculado no
 * fuso da loja, pelo banco de fusos.
 */
describe('fuso da loja (America/Sao_Paulo)', () => {
  it('a data do painel é a meia-noite da LOJA, não a de UTC', () => {
    expect(inicioDaLoja('2026-09-24').toISOString()).toBe(
      '2026-09-24T03:00:00.000Z',
    );
    expect(inicioDaLoja('2026-09-24T22:30:00').toISOString()).toBe(
      '2026-09-25T01:30:00.000Z',
    );
  });

  it('texto COM fuso vale o instante que ele diz', () => {
    expect(inicioDaLoja('2026-09-24T00:00:00Z').toISOString()).toBe(
      '2026-09-24T00:00:00.000Z',
    );
    expect(inicioDaLoja('2026-09-24T00:00:00-03:00').toISOString()).toBe(
      '2026-09-24T03:00:00.000Z',
    );
  });

  it('fim do dia = último milissegundo do dia na loja', () => {
    expect(fimDaLoja('2026-09-24').toISOString()).toBe(
      '2026-09-25T02:59:59.999Z',
    );
    // O painel antigo manda T23:59:59: vale até o fim daquele segundo.
    expect(fimDaLoja('2026-09-24T23:59:59').toISOString()).toBe(
      '2026-09-25T02:59:59.999Z',
    );
  });

  it('a venda do jantar (22h30 do dia 24) cai no dia 24, não no 25', () => {
    const venda = new Date('2026-09-25T01:30:00Z'); // 22h30 em Brasília, 24/09
    const { de, ate } = periodo({ de: '2026-09-24', ate: '2026-09-24' });
    expect(venda >= de && venda <= ate).toBe(true);
    const dia25 = periodo({ de: '2026-09-25', ate: '2026-09-25' });
    expect(venda >= dia25.de && venda <= dia25.ate).toBe(false);
  });

  it('"hoje" às 22h30 de Brasília ainda é o mesmo dia', () => {
    const agora = new Date('2026-09-25T01:30:00Z'); // 24/09, 22h30 na loja
    expect(paredeEm(agora)).toMatchObject({
      ano: 2026,
      mes: 9,
      dia: 24,
      hora: 22,
    });
    expect(inicioDoDia(agora).toISOString()).toBe('2026-09-24T03:00:00.000Z');
    expect(inicioDoDia(agora, undefined, -6).toISOString()).toBe(
      '2026-09-18T03:00:00.000Z',
    );
  });

  it('virada do mês pela LOJA: 30/09 às 23h ainda é setembro', () => {
    const agora = new Date('2026-10-01T02:00:00Z'); // 30/09, 23h na loja
    expect(inicioDoMes(agora).toISOString()).toBe('2026-09-01T03:00:00.000Z');
    expect(inicioDoMes(agora, undefined, -1).toISOString()).toBe(
      '2026-08-01T03:00:00.000Z',
    );
  });

  it('virada do ano pela loja', () => {
    const agora = new Date('2027-01-01T01:00:00Z'); // 31/12/2026, 22h na loja
    expect(inicioDoMes(agora).toISOString()).toBe('2026-12-01T03:00:00.000Z');
    expect(inicioDoMes(agora, undefined, 1).toISOString()).toBe(
      '2027-01-01T03:00:00.000Z',
    );
  });

  it('sem período: do dia 1 do mês (na loja) até agora', () => {
    const agora = new Date('2026-10-01T02:00:00Z');
    const { de, ate } = periodo({}, agora);
    expect(de.toISOString()).toBe('2026-09-01T03:00:00.000Z');
    expect(ate).toBe(agora);
  });
});
