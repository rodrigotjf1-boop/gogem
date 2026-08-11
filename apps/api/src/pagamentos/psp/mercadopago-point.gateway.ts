const BASE = 'https://api.mercadopago.com';

/** Status normalizado da cobrança no Point (agnóstico do wire do MP). */
export type PointStatus = 'pending' | 'approved' | 'cancelled' | 'error';

/**
 * Forma REAL do pagamento a partir do `payment_type_id` do MP — o cliente
 * escolhe crédito/débito/voucher na maquininha, então só sabemos depois de
 * aprovado. Serve pra relatório de taxas (crédito ≠ débito ≠ voucher).
 * ⚠️ VR/VA (Alelo/Sodexo/…) costumam vir como `debit_card`; distinguir a
 * bandeira exige o `payment_method_id` (coluna futura) — aqui fica 'debito'.
 */
export function normalizarTipoPagamento(paymentTypeId?: string): string {
  switch ((paymentTypeId ?? '').toLowerCase()) {
    case 'credit_card':
      return 'credito';
    case 'debit_card':
      return 'debito';
    case 'prepaid_card':
      return 'pre-pago';
    case 'voucher':
    case 'ticket':
    case 'account_money':
      return 'voucher';
    default:
      return paymentTypeId ? String(paymentTypeId) : 'outro';
  }
}

/** Marcas de vale-refeição/alimentação (o cartão vem como debit_card no MP). */
const MARCAS_VOUCHER = [
  'alelo',
  'sodexo',
  'ticket',
  'refeic',
  'aliment',
  'vale',
  'greencard',
  'planvale',
  'vr',
  'ben',
];

/** `payment_method_id` do MP indica vale-refeição? (ex.: 'alelo', 'vr'). */
export function ehBandeiraVoucher(bandeira?: string): boolean {
  const b = (bandeira ?? '').toLowerCase();
  if (!b) return false;
  if (b === 'vr' || b === 'ben') return true; // exatos (evita casar 'verve' etc.)
  return MARCAS_VOUCHER.some((m) => m.length > 2 && b.includes(m));
}

/**
 * Classifica a forma real: `tipo` (credito|debito|voucher|…) + `bandeira`
 * (payment_method_id, ex.: visa|master|elo|alelo). Se o MP marcou a compra como
 * cartão mas a bandeira é de vale, reclassifica como 'voucher' (VR/Alelo vêm
 * como debit_card).
 */
export function classificarPagamento(
  paymentTypeId?: string,
  paymentMethodId?: string,
): { tipo: string; bandeira: string | null } {
  const bandeira = paymentMethodId
    ? String(paymentMethodId).toLowerCase()
    : null;
  let tipo = normalizarTipoPagamento(paymentTypeId);
  if (tipo !== 'voucher' && ehBandeiraVoucher(bandeira ?? undefined)) {
    tipo = 'voucher';
  }
  return { tipo, bandeira };
}

export interface CriarPointInput {
  amountCents: number;
  orderId: string;
  /** 'credit' | 'debit'. */
  tipo: string;
}

export interface PointIntentCriado {
  intentId: string;
  state: string;
}

/**
 * Gateway do Mercado Pago Point Smart em **modo PDV** (Payment Intents API).
 * O totem cria uma intent para o `deviceId` da loja → a maquininha acende e pede
 * o cartão → o resultado volta por webhook + polling. Reusa o access token do MP
 * (mesmo do PIX). Credencial só no backend.
 *
 * ⚠️ O MP está migrando payment-intents → Orders API. TODO o formato do fio
 * (endpoints/campos/estados) está ISOLADO aqui — migrar depois é trocar só este
 * arquivo, sem tocar no provider/tela.
 */
export class MercadoPagoPointGateway {
  constructor(
    private readonly accessToken: string,
    public readonly deviceId: string,
  ) {}

  /** Garante o device em modo PDV (integrado) — idempotente. */
  async garantirModoPdv(): Promise<void> {
    const res = await fetch(
      `${BASE}/point/integration-api/devices/${this.deviceId}`,
      {
        method: 'PATCH',
        headers: this._headers(),
        body: JSON.stringify({ operating_mode: 'PDV' }),
      },
    );
    if (!res.ok && res.status !== 409) {
      const txt = await res.text().catch(() => '');
      throw new Error(`Point operating_mode ${res.status}: ${txt}`);
    }
  }

  async criarIntent(input: CriarPointInput): Promise<PointIntentCriado> {
    // NÃO forçamos `payment.type`: a maquininha pergunta crédito/débito/voucher
    // na tela dela. Forçar o tipo depende de o adquirente da conta habilitar
    // cada um — débito vinha recusado com "payment.type does not match
    // credit_card". Sem forçar, funciona pra qualquer configuração de conta.
    // (input.tipo segue guardado no PointPayment, só p/ relatório.)
    const res = await fetch(
      `${BASE}/point/integration-api/devices/${this.deviceId}/payment-intents`,
      {
        method: 'POST',
        headers: { ...this._headers(), 'X-Idempotency-Key': input.orderId },
        body: JSON.stringify({
          amount: input.amountCents, // Point API usa CENTAVOS (int)
          additional_info: {
            external_reference: input.orderId,
            print_on_terminal: true,
          },
        }),
      },
    );
    if (!res.ok) {
      const txt = await res.text().catch(() => '');
      throw new Error(`Point payment-intent ${res.status}: ${txt}`);
    }
    const b = (await res.json()) as { id?: string; state?: string };
    if (!b.id) throw new Error('Point não devolveu o id da intent.');
    return { intentId: String(b.id), state: String(b.state ?? 'OPEN') };
  }

  /** Status atual da intent (normalizado). */
  async consultar(
    intentId: string,
  ): Promise<{ status: PointStatus; paymentId?: string }> {
    const res = await fetch(
      `${BASE}/point/integration-api/payment-intents/${intentId}`,
      { headers: this._headers() },
    );
    if (!res.ok) return { status: 'error' };
    const b = (await res.json()) as {
      state?: string;
      payment?: { id?: string; status?: string };
    };
    return {
      status: this._mapState(b.state ?? '', b.payment?.status),
      paymentId: b.payment?.id ? String(b.payment.id) : undefined,
    };
  }

  /**
   * Detalhe do pagamento aprovado (GET /v1/payments/:id) — só pra descobrir a
   * forma REAL escolhida na maquininha. Chamado UMA vez, na virada pra aprovado.
   */
  async consultarPagamento(
    paymentId: string,
  ): Promise<{ tipo: string; bandeira: string | null }> {
    const res = await fetch(`${BASE}/v1/payments/${paymentId}`, {
      headers: this._headers(),
    });
    if (!res.ok) throw new Error(`Point payment ${res.status}`);
    const b = (await res.json()) as {
      payment_type_id?: string;
      payment_method_id?: string;
    };
    return classificarPagamento(b.payment_type_id, b.payment_method_id);
  }

  /** Cancela a intent (só enquanto não finalizada). */
  async cancelar(intentId: string): Promise<void> {
    await fetch(
      `${BASE}/point/integration-api/devices/${this.deviceId}/payment-intents/${intentId}`,
      { method: 'DELETE', headers: this._headers() },
    ).catch(() => undefined);
  }

  _headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.accessToken}`,
      'Content-Type': 'application/json',
    };
  }

  _mapState(state: string, paymentStatus?: string): PointStatus {
    switch (state.toUpperCase()) {
      case 'FINISHED':
        // Finalizada: o desfecho está no pagamento vinculado (quando presente).
        if (paymentStatus) {
          return paymentStatus === 'approved' ? 'approved' : 'error';
        }
        return 'approved';
      case 'CANCELED':
      case 'ABANDONED':
        return 'cancelled';
      case 'ERROR':
        return 'error';
      default: // OPEN | ON_TERMINAL | PROCESSING | …
        return 'pending';
    }
  }
}

/** Uma maquininha Point da conta (para o admin escolher o device_id). */
export interface PointDevice {
  id: string;
  posId?: number;
  operatingMode?: string;
}

/**
 * Lista as maquininhas Point da conta (GET /point/integration-api/devices) — só
 * precisa do access token (sem device_id), então serve pro admin descobrir o
 * device_id antes de salvá-lo. Não expõe credencial.
 */
export async function listarPointDevices(
  accessToken: string,
): Promise<PointDevice[]> {
  const res = await fetch(`${BASE}/point/integration-api/devices`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    throw new Error(`Point devices ${res.status}: ${txt}`);
  }
  const b = (await res.json()) as { devices?: any[] };
  return (b.devices ?? []).map((d) => ({
    id: String(d.id),
    posId: typeof d.pos_id === 'number' ? d.pos_id : undefined,
    operatingMode: d.operating_mode ? String(d.operating_mode) : undefined,
  }));
}

/**
 * Extrai o id da payment intent do webhook do Point (`point_integration_wh`).
 * Sem credencial (só lê o corpo/query), então o handler acha a cobrança antes de
 * resolver o gateway do tenant.
 */
export function parsePointWebhook(
  body: unknown,
  query: Record<string, unknown>,
): { intentId: string } | null {
  const b = (body ?? {}) as Record<string, any>;
  const tipo = b.topic ?? b.type ?? query['topic'] ?? query['type'];
  if (tipo && !String(tipo).includes('point')) return null;
  const id =
    b?.data?.id ?? b?.id ?? query['data.id'] ?? query['id'] ?? b?.resource;
  if (!id) return null;
  return { intentId: String(id) };
}
