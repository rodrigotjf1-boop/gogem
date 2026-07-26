import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';

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

    const dispositivo = await TenantContext.runAsSystem(() =>
      this.prisma.dispositivo.findFirst({ where: { token } }),
    );

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
