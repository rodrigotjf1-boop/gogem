import { Injectable, UnauthorizedException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantContext } from '../../tenant/tenant-context';
import { CatalogoPublicacaoService } from '../../catalogo/catalogo-publicacao.service';
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
  ) {}

  async publicar(token: string): Promise<{ alterados: number }> {
    const t = (token ?? '').trim();
    if (!t) throw new UnauthorizedException('X-Sync-Token ausente.');

    // Acha a loja pelo token que ela já usa na integração (cross-tenant).
    // O `await` dentro do runAsSystem mantém o contexto de sistema vivo até o
    // Prisma rodar (callback síncrono → ForbiddenException). Ver DeviceTokenGuard.
    const integ = await TenantContext.runAsSystem(async () => {
      const row = await this.prisma.integracao.findFirst({
        where: {
          tipo: 'regem',
          ativo: true,
          config: {
            path: ['token'],
            equals: t,
          } as Prisma.JsonFilter,
        },
        select: { tenantId: true },
      });
      return row;
    });
    if (!integ) throw new UnauthorizedException('Token inválido.');

    return TenantContext.run({ tenantId: integ.tenantId }, async () => {
      const { alterados } = await this.imports.sincronizarLinkados();
      if (alterados > 0) await this.publicacao.publicar(null);
      return { alterados };
    });
  }
}
