import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

/**
 * Payload do JWT da ORGANIZAÇÃO. `tipo: 'org'` separa do token do cliente (que
 * carrega `tenant`) — um token de cliente NUNCA passa por aqui (e vice-versa).
 */
export interface OrgJwtPayload {
  sub: string; // orgUsuarioId
  tipo: 'org';
  papel: string;
  email: string;
}

/** Usuário org resolvido do token → `req.user` nas rotas do console. */
export interface OrgAuthUser {
  orgUserId: string;
  papel: string;
  email: string;
}

/**
 * OrgJwtStrategy — estratégia passport nomeada 'org-jwt', separada da 'jwt' do
 * cliente. Reusa o mesmo `JWT_SECRET`, mas só aceita tokens com `tipo: 'org'`.
 */
@Injectable()
export class OrgJwtStrategy extends PassportStrategy(Strategy, 'org-jwt') {
  constructor(config: ConfigService) {
    const secret = config.get<string>('JWT_SECRET');
    if (!secret) {
      throw new Error('JWT_SECRET não configurado (ver .env.example).');
    }
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  validate(payload: OrgJwtPayload): OrgAuthUser {
    if (payload?.tipo !== 'org' || !payload?.sub) {
      throw new UnauthorizedException('Token não é da organização.');
    }
    return {
      orgUserId: payload.sub,
      papel: payload.papel,
      email: payload.email,
    };
  }
}
