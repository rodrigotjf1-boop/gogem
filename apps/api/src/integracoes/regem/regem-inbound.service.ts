import { Injectable, UnauthorizedException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantContext } from '../../tenant/tenant-context';
import { CatalogoPublicacaoService } from '../../catalogo/catalogo-publicacao.service';
import {
  CancelamentoService,
  CancelamentoResultado,
} from '../../pagamentos/cancelamento.service';
import { RegemImportService } from './regem-import.service';

/**
 * Entrada PUSH do Regem: o botão "Publicar no GoGeM" (no Regem) chama isto para
 * refletir na hora as pausas/edições, sem esperar o poller. Autentica pelo MESMO
 * `X-Sync-Token` que a loja já usa entre os dois (guardado em Integracao.config),
 * então acha o tenant por ele (cross-tenant via runAsSystem) e roda o sync dos
 * linkados + republica. Complementa o poller (rede de segurança).
 */
@Injectable()
export class RegemInboundService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly imports: RegemImportService,
    private readonly publicacao: CatalogoPublicacaoService,
    private readonly cancelamento: CancelamentoService,
  ) {}

  async publicar(token: string): Promise<{ alterados: number }> {
    const tenantId = await this.tenantPorToken(token);
    return TenantContext.run({ tenantId }, async () => {
      const { alterados } = await this.imports.sincronizarLinkados();
      if (alterados > 0) await this.publicacao.publicar(null);
      return { alterados };
    });
  }

  /**
   * Cancelamento pedido pelo Regem (atendente cancelou o cupom) COM estorno
   * eletrônico (cartão/PIX). Autentica pelo mesmo X-Sync-Token; acha o tenant e
   * roda o cancelamento no contexto dele. Idempotente pela idempotencyKey.
   */
  async cancelarPedido(
    token: string,
    body: { idempotencyKey?: string; regemComandaId?: string; motivo?: string },
  ): Promise<CancelamentoResultado> {
    const tenantId = await this.tenantPorToken(token);
    return TenantContext.run({ tenantId }, () =>
      this.cancelamento.cancelarPorChave(
        {
          idempotencyKey: body.idempotencyKey,
          regemComandaId: body.regemComandaId,
        },
        body.motivo ?? 'Cancelado no Regem',
        'regem',
      ),
    );
  }

  /**
   * Acha o tenant pela token da integração `regem` (cross-tenant via runAsSystem).
   * O `await` dentro do runAsSystem mantém o contexto de sistema vivo até o Prisma
   * rodar (callback síncrono → ForbiddenException). Ver DeviceTokenGuard.
   */
  private async tenantPorToken(token: string): Promise<string> {
    const t = (token ?? '').trim();
    if (!t) throw new UnauthorizedException('X-Sync-Token ausente.');
    const integ = await TenantContext.runAsSystem(async () => {
      return this.prisma.integracao.findFirst({
        where: {
          tipo: 'regem',
          ativo: true,
          config: { path: ['token'], equals: t } as Prisma.JsonFilter,
        },
        select: { tenantId: true },
      });
    });
    if (!integ) throw new UnauthorizedException('Token inválido.');
    return integ.tenantId;
  }
}
