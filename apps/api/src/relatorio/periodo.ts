import { fimDaLoja, inicioDaLoja, inicioDoMes } from '../common/fuso-loja';

/**
 * O período de um relatório, em instantes — lido no fuso da LOJA (ERR-014). O painel manda
 * as datas do filtro (`YYYY-MM-DD`); `de` vira a meia-noite desse dia na loja e `ate`, o fim
 * dele. Sem `de`/`ate`: do dia 1 do mês corrente (na loja) até agora.
 */
export function periodo(
  q: { de?: string; ate?: string },
  agora = new Date(),
): { de: Date; ate: Date } {
  return {
    de: q.de ? inicioDaLoja(q.de) : inicioDoMes(agora),
    ate: q.ate ? fimDaLoja(q.ate) : agora,
  };
}
