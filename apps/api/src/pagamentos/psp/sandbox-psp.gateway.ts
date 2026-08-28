import {
  CriarPixInput,
  PixChargeCreated,
  PixStatus,
  PspGateway,
  RefundResult,
} from './psp-gateway';

/** Segundos até o sandbox "aprovar" sozinho (simula o cliente pagando). */
const APROVA_APOS_SEG = 6;
/** Validade do QR no sandbox. */
const EXPIRA_APOS_SEG = 180;

/**
 * PSP de bancada (dev/staging/teste): gera um QR fake e aprova sozinho depois de
 * alguns segundos — o polling do totem enxerga a aprovação como num PSP real,
 * sem credencial. O carimbo de tempo vai no `pspRef` (stateless), então
 * `consultar` decide aprovado/pendente/expirado só pela idade da cobrança.
 */
export class SandboxPspGateway implements PspGateway {
  readonly nome = 'sandbox';

  constructor(private readonly agoraMs: () => number = () => Date.now()) {}

  async criarPix(input: CriarPixInput): Promise<PixChargeCreated> {
    const criadoEm = this.agoraMs();
    const pspRef = `sbx_${criadoEm}_${input.orderId}`;
    const copiaECola = this._emvFake(input, criadoEm);
    return {
      pspRef,
      copiaECola,
      qrImage: null, // o app desenha o QR a partir do copia-e-cola
      expiresAt: new Date(criadoEm + EXPIRA_APOS_SEG * 1000),
    };
  }

  async consultar(pspRef: string): Promise<PixStatus> {
    const criadoEm = this._criadoEmDe(pspRef);
    if (criadoEm == null) return 'error';
    const idadeSeg = (this.agoraMs() - criadoEm) / 1000;
    if (idadeSeg >= EXPIRA_APOS_SEG) return 'expired';
    if (idadeSeg >= APROVA_APOS_SEG) return 'approved';
    return 'pending';
  }

  async reembolsar(paymentId: string): Promise<RefundResult> {
    // Bancada: estorno "aprovado" na hora, sem rede/credencial.
    return { refundId: `sbx_refund_${paymentId}`, status: 'approved' };
  }

  parseWebhook(): { pspRef: string } | null {
    // Sandbox não recebe webhook — a aprovação vem pelo polling.
    return null;
  }

  _criadoEmDe(pspRef: string): number | null {
    const m = /^sbx_(\d+)_/.exec(pspRef);
    return m ? Number(m[1]) : null;
  }

  _emvFake(input: CriarPixInput, criadoEm: number): string {
    const reais = (input.amountCents / 100).toFixed(2);
    return (
      '00020126BR.GOV.BCB.PIX.SANDBOX' +
      `52040000530398654${reais.length.toString().padStart(2, '0')}${reais}` +
      `5802BR5909GoGeM SBX6009SAO PAULO62${input.orderId.length
        .toString()
        .padStart(2, '0')}${input.orderId}_${criadoEm}6304FAKE`
    );
  }
}
