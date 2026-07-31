import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OD_AUDIENCE } from './open-delivery-token.service';

/**
 * Guard das rotas PÚBLICAS do Open Delivery (`/open-delivery/v1/...`, exceto o
 * /oauth/token). Valida o Bearer emitido pelo /oauth/token (audiência
 * `open-delivery`), confere o escopo exigido pela rota (via @OdScope) e injeta
 * `req.user = { tenantId, ... }` para o TenantContextInterceptor abrir o tenant.
 */
@Injectable()
export class OpenDeliveryAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      user?: unknown;
      odEscopos?: string[];
    }>();
    const header = req.headers['authorization'];
    const token =
      header && header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new UnauthorizedException('Token ausente.');

    let payload: {
      sub?: string;
      tenantId?: string;
      escopos?: string[];
      aud?: string;
    };
    try {
      payload = await this.jwt.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('Token inválido ou expirado.');
    }
    if (payload.aud !== OD_AUDIENCE || !payload.tenantId) {
      throw new UnauthorizedException('Token não é do Open Delivery.');
    }

    // Escopo exigido pela rota (metadado @OdScope), se houver.
    const exigido = Reflect.getMetadata('od:scope', context.getHandler()) as
      string | undefined;
    const escopos = payload.escopos ?? [];
    if (exigido && !escopos.includes(exigido)) {
      throw new ForbiddenException(`Escopo '${exigido}' não concedido.`);
    }

    req.user = {
      tenantId: payload.tenantId,
      userId: payload.sub,
      papel: 'open_delivery',
    };
    req.odEscopos = escopos;
    return true;
  }
}

/** Marca o escopo exigido por uma rota OD (lido pelo OpenDeliveryAuthGuard). */
export const OdScope =
  (escopo: string): MethodDecorator =>
  (_t, _k, descriptor: PropertyDescriptor) => {
    Reflect.defineMetadata('od:scope', escopo, descriptor.value);
    return descriptor;
  };
