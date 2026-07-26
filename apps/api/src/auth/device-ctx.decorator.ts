import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { DeviceUser } from './device-token.guard';

/**
 * @DeviceCtx() — injeta o dispositivo autenticado (`req.user`) no handler.
 * Só faz sentido em rotas protegidas pelo DeviceTokenGuard; em rota JWT o
 * `req.user` é o `AuthenticatedUser`, então o resultado pode não ter `deviceId`.
 */
export const DeviceCtx = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): DeviceUser | undefined => {
    const req = ctx.switchToHttp().getRequest<{ user?: DeviceUser }>();
    return req.user;
  },
);
