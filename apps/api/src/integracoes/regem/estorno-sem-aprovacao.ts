/**
 * A exceção do estorno (Padrão DMS do hub, decisão F5-10; pacote comum `conferirEstornoSemAprovacao`).
 *
 * Devolver o dinheiro ao cliente, por um cancelamento que uma PESSOA fez no produto dono da venda (o Regem), não pede
 * aprovação aqui. As três condições da regra, no GoGeM:
 *  1. a venda é do GoGeM — o pedido e o pagamento são procurados só na empresa do token (`TenantContext` + o escopo do
 *     Prisma); de outra empresa, ou inexistente, não há o que estornar;
 *  2. o cancelamento foi feito por uma pessoa — é o `canceladoPor` que o Regem manda (esta função);
 *  3. a devolução não passa do que foi pago — o estorno é sempre o TOTAL do próprio pagamento, uma vez só (`refunded`
 *     segura a segunda; `CancelamentoService.estornar`).
 *
 * Sem o campo (o Regem de antes desta versão, e os avisos que ele já tinha na fila): aceito como antes. Do Regem, esse
 * aviso só nasce no cancelamento feito por uma pessoa (o gestor com a senha, ou pelo WhatsApp dele).
 */
export const QUEM_CANCELOU = ['pessoa', 'agente'] as const;
export type QuemCancelou = (typeof QUEM_CANCELOU)[number];

/** A mensagem do pacote comum, para o Regem mostrar a mesma frase que os outros produtos. */
export const MSG_ESTORNO_SO_DE_PESSOA =
  'Sem aprovação no destino, só sai o estorno de um cancelamento feito por uma pessoa no produto dono da venda.';

export const MSG_QUEM_CANCELOU_INVALIDO =
  'canceladoPor precisa ser "pessoa" ou "agente".';

export type RecusaDoEstorno = {
  /** O nome do problema no pacote comum: `regra-invalida` vira 422, `parametro-invalido` vira 400. */
  tipo: 'regra-invalida' | 'parametro-invalido';
  mensagem: string;
};

/** Nulo = pode estornar. Função pura: a rota traduz a recusa para a resposta HTTP (V1). */
export function conferirQuemCancelou(valor: unknown): RecusaDoEstorno | null {
  if (valor === undefined || valor === null) return null;
  if (valor === 'pessoa') return null;
  if (valor === 'agente') {
    return { tipo: 'regra-invalida', mensagem: MSG_ESTORNO_SO_DE_PESSOA };
  }
  return { tipo: 'parametro-invalido', mensagem: MSG_QUEM_CANCELOU_INVALIDO };
}
