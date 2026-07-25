import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * JwtAuthGuard — protege rotas exigindo Bearer token válido (estratégia 'jwt').
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
