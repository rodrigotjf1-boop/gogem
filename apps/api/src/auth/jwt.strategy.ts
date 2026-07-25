import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

/**
 * Payload assinado no JWT (ver AuthService).
 */
export interface JwtPayload {
  sub: string; // userId
  tenant: string; // tenantId
  papel: string;
  email: string;
}

/**
 * Usuário resolvido a partir do token e injetado em `req.user`.
 */
export interface AuthenticatedUser {
  userId: string;
  tenantId: string;
  papel: string;
  email: string;
}

/**
 * JwtStrategy — valida o Bearer token e materializa `req.user`. O `tenant` do
 * payload alimenta o TenantContextInterceptor (multi-tenant, CLAUDE.md §2).
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
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

  validate(payload: JwtPayload): AuthenticatedUser {
    if (!payload?.sub || !payload?.tenant) {
      throw new UnauthorizedException('Token sem sujeito/tenant.');
    }
    return {
      userId: payload.sub,
      tenantId: payload.tenant,
      papel: payload.papel,
      email: payload.email,
    };
  }
}
