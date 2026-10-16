import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { segredoDa } from '../../integracao/segredos';
import { TenantContext } from '../../tenant/tenant-context';
import { avisoAutentico, dataIdDaQuery } from './assinatura-mp';
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
 *
 * O access token vem cifrado do banco (`segredoDa`). Cifrado que não abre é
 * erro (503), nunca "sem integração": cair no fallback trocaria a conta.
 */
/** O que o aviso (webhook) do Mercado Pago traz para conferir a origem. */
export interface AvisoMercadoPago {
  xSignature?: string;
  xRequestId?: string;
  query: Record<string, unknown>;
}

@Injectable()
export class PspResolver {
  private readonly logger = new Logger(PspResolver.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Resolve o gateway do tenant do CONTEXTO atual (device/JWT já autenticado). */
  async resolver(): Promise<PspGateway> {
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'mercadopago', ativo: true },
    });
    const token = segredoDa(integ, 'accessToken');
    return token ? new MercadoPagoPspGateway(token) : this.fallbackEnv();
  }

  /**
   * Gateway do Point Smart (cartão) do tenant do contexto: precisa do access
   * token E do `deviceId` salvos na integração mercadopago. null = não
   * configurado (a loja não tem maquininha vinculada).
   */
  async resolverPoint(
    deviceIdOverride?: string | null,
  ): Promise<MercadoPagoPointGateway | null> {
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'mercadopago', ativo: true },
    });
    const cfg = integ?.config as Record<string, string> | null;
    const token = segredoDa(integ, 'accessToken');
    // Maquininha DO totem (multi-terminal) tem prioridade; senão a padrão da loja.
    const deviceId = deviceIdOverride?.trim() || cfg?.deviceId;
    return token && deviceId
      ? new MercadoPagoPointGateway(token, deviceId)
      : null;
  }

  /** Access token do MP da loja (sem exigir device) — p/ listar maquininhas. */
  async tokenMercadoPago(): Promise<string | null> {
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'mercadopago', ativo: true },
    });
    return segredoDa(integ, 'accessToken') || null;
  }

  /**
   * Confere se o aviso veio do Mercado Pago, com a assinatura secreta dos
   * avisos da loja do contexto. Recusa (401) sem consultar o Mercado Pago quando
   * a loja não tem a assinatura configurada, quando o id assinado não é o do
   * aviso ou quando a assinatura não confere. `idDoAviso` = o id pelo qual o
   * aviso achou o pagamento.
   */
  async conferirAviso(
    aviso: AvisoMercadoPago,
    idDoAviso: string,
  ): Promise<void> {
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'mercadopago', ativo: true },
    });
    const segredo = segredoDa(integ, 'segredoDosAvisos');
    const dataId = dataIdDaQuery(aviso.query);
    let motivo: string | null = null;
    if (!segredo) {
      motivo = 'a loja não tem a assinatura secreta dos avisos configurada';
    } else if (dataId && dataId.toLowerCase() !== idDoAviso.toLowerCase()) {
      motivo = 'o id assinado não é o do aviso';
    } else if (
      !avisoAutentico({
        xSignature: aviso.xSignature,
        xRequestId: aviso.xRequestId,
        dataId,
        segredo,
      })
    ) {
      motivo = aviso.xSignature
        ? 'a assinatura não confere'
        : 'o aviso veio sem assinatura';
    }
    if (motivo) {
      // Só o motivo e a empresa — nunca o segredo nem a assinatura.
      this.logger.warn(
        `Aviso do Mercado Pago recusado (empresa ${TenantContext.getTenantId()}): ${motivo}.`,
      );
      throw new UnauthorizedException('Aviso sem assinatura válida.');
    }
  }

  private fallbackEnv(): PspGateway {
    const psp = (process.env.GOGEM_PSP ?? 'sandbox').toLowerCase();
    if (psp === 'mercadopago' && process.env.MERCADOPAGO_ACCESS_TOKEN) {
      return new MercadoPagoPspGateway(process.env.MERCADOPAGO_ACCESS_TOKEN);
    }
    return new SandboxPspGateway();
  }
}
