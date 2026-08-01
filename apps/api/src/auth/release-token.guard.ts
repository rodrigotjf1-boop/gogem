import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

/** Header do token de publicação de release do totem. */
export const RELEASE_TOKEN_HEADER = 'x-release-token';

/**
 * ReleaseTokenGuard — protege a publicação de releases do APK do totem.
 *
 * O APK é o produto (o mesmo para todas as lojas), então publicar é ação do DMS,
 * não de cada lojista. Autentica por um segredo de sistema (`KIOSK_RELEASE_TOKEN`)
 * enviado no header `X-Release-Token`, independente do JWT do painel. Sem a env
 * definida, a publicação fica desligada (fail-closed).
 */
@Injectable()
export class ReleaseTokenGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const esperado = process.env.KIOSK_RELEASE_TOKEN;
    if (!esperado) {
      throw new UnauthorizedException(
        'Publicação de release desativada: defina KIOSK_RELEASE_TOKEN na API.',
      );
    }
    const req = context
      .switchToHttp()
      .getRequest<{ headers: Record<string, unknown> }>();
    const raw = req.headers[RELEASE_TOKEN_HEADER];
    const token = Array.isArray(raw) ? raw[0] : raw;
    if (typeof token !== 'string' || token !== esperado) {
      throw new UnauthorizedException('Token de release inválido.');
    }
    return true;
  }
}
