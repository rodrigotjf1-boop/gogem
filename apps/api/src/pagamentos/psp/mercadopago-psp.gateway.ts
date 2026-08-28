import {
  CriarPixInput,
  PixChargeCreated,
  PixStatus,
  PspGateway,
  RefundResult,
} from './psp-gateway';

const BASE = 'https://api.mercadopago.com';

/**
 * PSP Mercado Pago (F8). PIX por QR dinâmico. O access token (credencial) fica
 * no backend (env `MERCADOPAGO_ACCESS_TOKEN`) — o app nunca o vê. Idempotência
 * no MP pela `X-Idempotency-Key` = orderId.
 *
 * Docs: POST /v1/payments (payment_method_id=pix) devolve
 * point_of_interaction.transaction_data.{qr_code, qr_code_base64}. Status por
 * GET /v1/payments/:id. Webhook manda { type:'payment', data:{ id } }.
 */
export class MercadoPagoPspGateway implements PspGateway {
  readonly nome = 'mercadopago';

  constructor(private readonly accessToken: string) {}

  async criarPix(input: CriarPixInput): Promise<PixChargeCreated> {
    const res = await fetch(`${BASE}/v1/payments`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json',
        'X-Idempotency-Key': input.orderId,
      },
      body: JSON.stringify({
        transaction_amount: Number((input.amountCents / 100).toFixed(2)),
        description: input.descricao ?? 'Pedido totem GoGeM',
        payment_method_id: 'pix',
        payer: {
          email: 'cliente-totem@gogem.com.br',
          first_name: 'Cliente',
          ...(input.cpfCnpj
            ? {
                identification: {
                  type: input.cpfCnpj.length > 11 ? 'CNPJ' : 'CPF',
                  number: input.cpfCnpj,
                },
              }
            : {}),
        },
      }),
    });
    if (!res.ok) {
      const txt = await res.text().catch(() => '');
      throw new Error(`Mercado Pago ${res.status}: ${txt}`);
    }
    const b = (await res.json()) as any;
    const tx = b?.point_of_interaction?.transaction_data ?? {};
    const copiaECola = tx.qr_code as string | undefined;
    if (!copiaECola) {
      throw new Error('Mercado Pago não devolveu o QR (qr_code ausente).');
    }
    const base64 = tx.qr_code_base64 as string | undefined;
    return {
      pspRef: String(b.id),
      copiaECola,
      qrImage: base64 ? `data:image/png;base64,${base64}` : null,
      expiresAt: b.date_of_expiration ? new Date(b.date_of_expiration) : null,
    };
  }

  async consultar(pspRef: string): Promise<PixStatus> {
    const res = await fetch(`${BASE}/v1/payments/${pspRef}`, {
      headers: { Authorization: `Bearer ${this.accessToken}` },
    });
    if (!res.ok) return 'error';
    const b = (await res.json()) as any;
    return this._mapStatus(String(b?.status), String(b?.status_detail ?? ''));
  }

  /**
   * Estorno TOTAL (POST /v1/payments/:id/refunds sem `amount`). Vale para cartão
   * (Point) e PIX — o `paymentId` é sempre o id do pagamento em /v1/payments do
   * MP. `X-Idempotency-Key` evita estorno duplicado.
   */
  async reembolsar(
    paymentId: string,
    idempotencyKey?: string,
  ): Promise<RefundResult> {
    const res = await fetch(`${BASE}/v1/payments/${paymentId}/refunds`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json',
        ...(idempotencyKey ? { 'X-Idempotency-Key': idempotencyKey } : {}),
      },
      body: JSON.stringify({}), // sem amount = estorno TOTAL
    });
    if (!res.ok) {
      const txt = await res.text().catch(() => '');
      throw new Error(`Mercado Pago refund ${res.status}: ${txt}`);
    }
    const b = (await res.json()) as { id?: string | number; status?: string };
    return {
      refundId: b.id != null ? String(b.id) : '',
      status: String(b.status ?? 'approved'),
    };
  }

  parseWebhook(
    body: unknown,
    query: Record<string, unknown>,
  ): { pspRef: string } | null {
    return parseMercadoPagoWebhook(body, query);
  }

  _mapStatus(status: string, detail: string): PixStatus {
    switch (status) {
      case 'approved':
        return 'approved';
      case 'pending':
      case 'in_process':
      case 'authorized':
        return 'pending';
      case 'cancelled':
        return detail.includes('expired') ? 'expired' : 'cancelled';
      case 'rejected':
        return 'error';
      default:
        return 'pending';
    }
  }
}

/**
 * Extrai do webhook do Mercado Pago o id do pagamento a re-consultar. Não usa
 * credencial (só lê o corpo/query), então o handler acha a cobrança pelo pspRef
 * ANTES de resolver o gateway do tenant. Formato novo `{type:'payment',
 * data:{id}}` ou legado `?type=payment&data.id=`.
 */
export function parseMercadoPagoWebhook(
  body: unknown,
  query: Record<string, unknown>,
): { pspRef: string } | null {
  const b = (body ?? {}) as any;
  const tipo = b.type ?? b.topic ?? query['type'] ?? query['topic'];
  if (tipo && String(tipo) !== 'payment') return null;
  const id = b?.data?.id ?? query['data.id'] ?? query['id'] ?? b?.resource;
  if (!id) return null;
  return { pspRef: String(id) };
}
