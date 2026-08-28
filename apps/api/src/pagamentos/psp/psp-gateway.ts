/** Status normalizado de uma cobrança PIX (agnóstico de PSP). */
export type PixStatus =
  'pending' | 'approved' | 'expired' | 'cancelled' | 'error';

/** Resultado da criação de uma cobrança no PSP. */
export interface PixChargeCreated {
  /** id do pagamento no PSP (para consultar/casar webhook). */
  pspRef: string;
  /** EMV "copia e cola". */
  copiaECola: string;
  /** Imagem do QR como data URI (base64) — opcional. */
  qrImage: string | null;
  expiresAt: Date | null;
}

export interface CriarPixInput {
  amountCents: number;
  /** UUID do pedido — idempotência no PSP. */
  orderId: string;
  descricao?: string;
  cpfCnpj?: string;
}

/** Resultado de um estorno (refund) no PSP. */
export interface RefundResult {
  /** id do estorno no PSP. */
  refundId: string;
  /** status normalizado do estorno ('approved' | 'pending' | …). */
  status: string;
}

/**
 * Contrato do PSP de PIX. Cada PSP (Mercado Pago, Efí, Asaas…) é um adaptador;
 * o resto do backend só fala com esta interface. Credenciais ficam no adaptador,
 * nunca no app.
 */
export interface PspGateway {
  /** Nome do adaptador (gravado na cobrança: 'sandbox' | 'mercadopago'…). */
  readonly nome: string;

  criarPix(input: CriarPixInput): Promise<PixChargeCreated>;

  /** Consulta o status atual no PSP. */
  consultar(pspRef: string): Promise<PixStatus>;

  /**
   * Estorno TOTAL de um pagamento aprovado (cartão/PIX), pelo id do pagamento no
   * PSP (`POST /v1/payments/:id/refunds` sem amount = valor total).
   * `idempotencyKey` evita estorno duplicado no PSP.
   */
  reembolsar(paymentId: string, idempotencyKey?: string): Promise<RefundResult>;

  /**
   * Extrai do corpo/headers do webhook a referência do pagamento a re-consultar
   * (nunca confia no status do webhook cru — sempre re-consulta). null = ignora.
   */
  parseWebhook(
    body: unknown,
    query: Record<string, unknown>,
  ): { pspRef: string } | null;
}

/** Token de DI do gateway PSP ativo. */
export const PSP_GATEWAY = 'PSP_GATEWAY';
