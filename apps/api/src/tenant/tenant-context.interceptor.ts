import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { TenantContext, TenantStore } from './tenant-context';

/**
 * Usuário injetado no `req` pela estratégia JWT (ver auth/jwt.strategy.ts).
 */
interface RequestUser {
  userId?: string;
  tenantId?: string;
  papel?: string;
}

/**
 * TenantContextInterceptor — abre o escopo multi-tenant DEPOIS que o guard de
 * auth resolveu `req.user` (guards rodam antes de interceptors no Nest).
 *
 * O `tenant` do JWT alimenta o AsyncLocalStorage; todo o restante da requisição
 * (incluindo as queries do Prisma) roda dentro de `TenantContext.run`.
 *
 * TODO(S2): alimentar também a partir da auth de dispositivo
 *   (X-Sync-Token) quando ela existir — hoje só o JWT popula o contexto.
 */
@Injectable()
export class TenantContextInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<{ user?: RequestUser }>();
    const user = req.user;

    // Sem usuário autenticado (rotas públicas): segue sem abrir contexto — as
    // queries de bootstrap devem usar TenantContext.runAsSystem explicitamente.
    if (!user?.tenantId) {
      return next.handle();
    }

    const store: TenantStore = {
      tenantId: user.tenantId,
      userId: user.userId,
      papel: user.papel,
    };

    // Envolve a assinatura do handler no escopo de tenant para que as
    // continuações assíncronas (queries) enxerguem o AsyncLocalStorage.
    return new Observable((subscriber) =>
      TenantContext.run(store, () => next.handle().subscribe(subscriber)),
    );
  }
}
