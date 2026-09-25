/**
 * O GoGeM se IDENTIFICA em toda chamada ao Regem.
 *
 * O Regem autentica o GoGeM por um token de equipamento `servidor_local`, e uma empresa pode ter
 * vários — o do servidor da loja, sobras de teste, o criado para a integração. Para avisar o
 * GoGeM (cancelamento feito no Regem → estorno do cartão/PIX), o Regem precisa mandar de volta o
 * token que o GoGeM conhece; sem saber qual é, ele escolhia um qualquer e o GoGeM recusava (401).
 * Este cabeçalho diz ao Regem qual equipamento é o do GoGeM. Não autentica nada — quem autentica
 * é o token.
 */
export const CABECALHO_INTEGRADOR = { 'X-Integrador': 'gogem' } as const;
