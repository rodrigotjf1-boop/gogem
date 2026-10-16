import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import {
  PREFIXO_DO_RESUMO,
  resumoDoTokenDoDispositivo,
} from './token-do-dispositivo';

/** Header do token de dispositivo (totem). */
export const DEVICE_TOKEN_HEADER = 'x-device-token';

/**
 * Usuário de dispositivo injetado em `req.user`. Espelha o shape do usuário do
 * JWT (`AuthenticatedUser`) para que o TenantContextInterceptor abra o contexto
 * de tenant a partir de `req.user.tenantId` — SEM reimplementar o contexto.
 */
export interface DeviceUser {
  userId: null;
  tenantId: string;
  papel: 'dispositivo';
  deviceId: string;
  unidadeId: string | null;
}

/**
 * DeviceTokenGuard — autentica o totem pelo header `X-Device-Token`.
 *
 * O lookup roda em `TenantContext.runAsSystem` (não há tenant no contexto na
 * fase de guard — espelha o bootstrap do AuthService). Exige `pareado && ativo`.
 * Em sucesso, seta `req.user` com o `tenantId` do dispositivo; o interceptor
 * global (que roda DEPOIS dos guards) lê esse `tenantId` e abre o contexto
 * multi-tenant. Assim o middleware do Prisma isola as queries normalmente.
 */
@Injectable()
export class DeviceTokenGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context
      .switchToHttp()
      .getRequest<{ headers: Record<string, unknown>; user?: DeviceUser }>();

    const raw = req.headers[DEVICE_TOKEN_HEADER];
    const token = Array.isArray(raw) ? raw[0] : raw;
    if (!token || typeof token !== 'string') {
      throw new UnauthorizedException('Token de dispositivo ausente.');
    }

    // `await` dentro do runAsSystem mantém o contexto de sistema (ALS) vivo
    // durante a query + middleware (callback síncrono descartaria o contexto
    // antes do Prisma rodar → 403 fail-closed).
    // O banco guarda o resumo do token (quem lê o banco não vira um totem).
    // Transição: o totem pareado antes do resumo ainda tem o token puro na
    // coluna até a migration converter (PR seguinte, depois deste no ar — assim
    // nenhum container antigo recusa um totem no meio do deploy, e o app não se
    // despareia). Um valor que já tem a forma do resumo nunca casa como token puro:
    // quem copia o resumo do banco não entra.
    const tokenHash = resumoDoTokenDoDispositivo(token);
    const ehResumo = token.startsWith(PREFIXO_DO_RESUMO);
    const dispositivo = await TenantContext.runAsSystem(async () => {
      const dev = await this.prisma.dispositivo.findFirst({
        where: ehResumo
          ? { tokenHash }
          : { OR: [{ tokenHash }, { tokenHash: token }] },
      });
      return dev;
    });

    if (!dispositivo || !dispositivo.pareado || !dispositivo.ativo) {
      throw new UnauthorizedException('Dispositivo inválido ou revogado.');
    }

    req.user = {
      userId: null,
      tenantId: dispositivo.tenantId,
      papel: 'dispositivo',
      deviceId: dispositivo.id,
      unidadeId: dispositivo.unidadeId,
    };
    return true;
  }
}
