import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { DeviceTokenGuard, DEVICE_TOKEN_HEADER } from './device-token.guard';
import { JwtAuthGuard } from './jwt-auth.guard';

/**
 * JwtOrDeviceGuard — libera a rota se o JWT OU o token de dispositivo validar.
 *
 * Estratégia: se houver o header `X-Device-Token`, tenta o DeviceTokenGuard;
 * senão, cai no JwtAuthGuard (Bearer). Em ambos os caminhos `req.user.tenantId`
 * fica setado, então o TenantContextInterceptor global abre o contexto de
 * tenant normalmente — não há contexto reimplementado aqui.
 *
 * Usado no `GET /catalogo/publicado` (aceita totem ou usuário logado). O
 * smoke-test chama essa rota com JWT: continua passando pelo ramo JwtAuthGuard.
 */
@Injectable()
export class JwtOrDeviceGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtAuthGuard,
    private readonly device: DeviceTokenGuard,
  ) {}

  canActivate(context: ExecutionContext): boolean | Promise<boolean> {
    const req = context
      .switchToHttp()
      .getRequest<{ headers: Record<string, unknown> }>();

    if (req.headers[DEVICE_TOKEN_HEADER]) {
      return this.device.canActivate(context);
    }
    // AuthGuard('jwt').canActivate pode devolver boolean | Promise | Observable;
    // aqui só JWT (síncrono/promise), então normalizamos para Promise<boolean>.
    return Promise.resolve(
      this.jwt.canActivate(context) as boolean | Promise<boolean>,
    );
  }
}
