import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthenticatedUser } from './jwt.strategy';
import { PAPEL_HIERARQUIA, Papel, ROLES_KEY } from './roles.decorator';

/**
 * RolesGuard — RBAC por hierarquia de papel. Deve rodar DEPOIS do JwtAuthGuard
 * (precisa de `req.user`). `@Roles('gerente')` libera gerente e acima.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const papelMinimo = this.reflector.getAllAndOverride<Papel | undefined>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    // Rota sem @Roles: sem exigência de papel (basta estar autenticado).
    if (!papelMinimo) {
      return true;
    }

    const req = context
      .switchToHttp()
      .getRequest<{ user?: AuthenticatedUser }>();
    const papelUsuario = req.user?.papel as Papel | undefined;

    const nivelUsuario = papelUsuario
      ? PAPEL_HIERARQUIA.indexOf(papelUsuario)
      : -1;
    const nivelMinimo = PAPEL_HIERARQUIA.indexOf(papelMinimo);

    if (nivelUsuario < 0 || nivelUsuario < nivelMinimo) {
      throw new ForbiddenException('Papel insuficiente para esta operação.');
    }
    return true;
  }
}
