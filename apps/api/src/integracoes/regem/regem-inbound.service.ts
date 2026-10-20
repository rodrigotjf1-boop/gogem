import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantContext } from '../../tenant/tenant-context';
import { buscaDoSegredo } from '../../integracao/segredos';
import { CatalogoPublicacaoService } from '../../catalogo/catalogo-publicacao.service';
import {
  CancelamentoService,
  CancelamentoResultado,
} from '../../pagamentos/cancelamento.service';
import { RegemImportService } from './regem-import.service';
import type { AvisoConferido } from './regem-avisos.service';

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
    return this.publicarNoTenant(tenantId);
  }

  /** Sincroniza os linkados e republica se mudou (o "Publicar no GoGeM"). */
  private publicarNoTenant(tenantId: string): Promise<{ alterados: number }> {
    return TenantContext.run({ tenantId }, async () => {
      const { alterados } = await this.imports.sincronizarLinkados();
      if (alterados > 0) await this.publicacao.publicar(null);
      return { alterados };
    });
  }

  /**
   * Um aviso ASSINADO que já passou na conferência (`RegemAvisosService.conferir`): os dois
   * `tipo` do contrato 1.
   *  • `pedido.cancelado` — o mesmo cancelamento de hoje (`cancelarPorChave`, idempotente). Um
   *    aviso REPETIDO roda de novo e devolve o resultado atual: o Regem só repete quando não
   *    recebeu resposta ou quando o estorno eletrônico falhou (contrato §4).
   *    Pedido não encontrado → 422 `pedido-nao-encontrado` (não 404: na rota nova o Regem lê 404
   *    como "endereço errado" e esperaria 6 h);
   *  • `catalogo.publicar` — `{ alterados }` (§5).
   */
  async tratarAviso(aviso: AvisoConferido): Promise<unknown> {
    const { tenantId, corpo } = aviso;
    if (corpo.tipo === 'catalogo.publicar')
      return this.publicarNoTenant(tenantId);
    if (corpo.tipo !== 'pedido.cancelado') {
      throw new UnprocessableEntityException({
        code: 'tipo-desconhecido',
        message: `O GoGeM não trata o aviso "${String(corpo.tipo).slice(0, 60)}".`,
      });
    }
    const pedido = (corpo.pedido ?? {}) as Record<string, unknown>;
    const texto = (
      v: unknown,
      max: number,
      campo: string,
    ): string | undefined => {
      if (v === undefined || v === null) return undefined;
      if (typeof v !== 'string' || v.length > max) {
        throw new BadRequestException(
          `pedido.${campo} precisa ser texto de até ${max} caracteres.`,
        );
      }
      return v;
    };
    const idempotencyKey = texto(pedido.idempotencyKey, 120, 'idempotencyKey');
    const regemComandaId = texto(pedido.regemComandaId, 120, 'regemComandaId');
    const motivo = texto(pedido.motivo, 500, 'motivo');
    return TenantContext.run({ tenantId }, async () => {
      try {
        const r = await this.cancelamento.cancelarPorChave(
          { idempotencyKey, regemComandaId },
          motivo ?? 'Cancelado no Regem',
          'regem',
        );
        return r;
      } catch (err) {
        if (err instanceof NotFoundException) {
          throw new UnprocessableEntityException({
            code: 'pedido-nao-encontrado',
            message: err.message,
          });
        }
        throw err;
      }
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
   * O token fica cifrado no banco: a busca é pelo SHA-256 dele (`segredoBusca`).
   * A linha antiga ainda sem resumo (antes da migração do boot passar) é achada
   * pelo valor em claro — só casa enquanto o token não foi cifrado.
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
          OR: [
            { segredoBusca: buscaDoSegredo(t) },
            {
              segredoBusca: null,
              config: { path: ['token'], equals: t } as Prisma.JsonFilter,
            },
          ],
        },
        select: { tenantId: true },
      });
    });
    if (!integ) throw new UnauthorizedException('Token inválido.');
    return integ.tenantId;
  }
}
