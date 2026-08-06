import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MercadoPagoPspGateway } from './mercadopago-psp.gateway';
import { MercadoPagoPointGateway } from './mercadopago-point.gateway';
import { SandboxPspGateway } from './sandbox-psp.gateway';
import { PspGateway } from './psp-gateway';

/**
 * Escolhe o gateway PSP POR LOJA (multi-tenant): lê a integração `mercadopago`
 * ativa do tenant e usa o access token DELE. Sem integração configurada, cai no
 * fallback de ambiente (`GOGEM_PSP`/`MERCADOPAGO_ACCESS_TOKEN`, dev/operador
 * único) e, na ausência de tudo, no **sandbox** (QR de teste que aprova sozinho).
 * Assim cada lojista pluga a própria conta no admin — sem env por instância.
 */
@Injectable()
export class PspResolver {
  constructor(private readonly prisma: PrismaService) {}

  /** Resolve o gateway do tenant do CONTEXTO atual (device/JWT já autenticado). */
  async resolver(): Promise<PspGateway> {
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'mercadopago', ativo: true },
    });
    const token = (integ?.config as Record<string, string> | null)?.accessToken;
    return token ? new MercadoPagoPspGateway(token) : this.fallbackEnv();
  }

  /**
   * Gateway do Point Smart (cartão) do tenant do contexto: precisa do access
   * token E do `deviceId` salvos na integração mercadopago. null = não
   * configurado (a loja não tem maquininha vinculada).
   */
  async resolverPoint(): Promise<MercadoPagoPointGateway | null> {
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'mercadopago', ativo: true },
    });
    const cfg = integ?.config as Record<string, string> | null;
    const token = cfg?.accessToken;
    const deviceId = cfg?.deviceId;
    return token && deviceId
      ? new MercadoPagoPointGateway(token, deviceId)
      : null;
  }

  private fallbackEnv(): PspGateway {
    const psp = (process.env.GOGEM_PSP ?? 'sandbox').toLowerCase();
    if (psp === 'mercadopago' && process.env.MERCADOPAGO_ACCESS_TOKEN) {
      return new MercadoPagoPspGateway(process.env.MERCADOPAGO_ACCESS_TOKEN);
    }
    return new SandboxPspGateway();
  }
}
