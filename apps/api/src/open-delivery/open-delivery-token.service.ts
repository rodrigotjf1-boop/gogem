import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { OpenDeliveryTokenDto } from './dto/token.dto';

/** Claim de audiência que distingue o token OD do JWT de usuário. */
export const OD_AUDIENCE = 'open-delivery';
const TOKEN_TTL_SEG = 3600; // 1h

/**
 * Emissor de token do Open Delivery (OAuth2 client_credentials). O lookup do app
 * é por `clientId` GLOBAL (cross-tenant) — roda em `runAsSystem` porque não há
 * tenant no contexto ainda; o token emitido carrega o tenant do app.
 */
@Injectable()
export class OpenDeliveryTokenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async emitir(dto: OpenDeliveryTokenDto): Promise<{
    access_token: string;
    token_type: 'Bearer';
    expires_in: number;
  }> {
    const app = await TenantContext.runAsSystem(async () =>
      this.prisma.openDeliveryApp.findFirst({
        where: { clientId: dto.client_id },
      }),
    );
    const valido =
      !!app &&
      app.ativo &&
      (await bcrypt.compare(dto.client_secret, app.clientSecretHash));
    if (!app || !valido) {
      throw new UnauthorizedException('client_id/client_secret inválidos.');
    }

    await TenantContext.runAsSystem(async () =>
      this.prisma.openDeliveryApp.update({
        where: { id: app.id },
        data: { ultimoUso: new Date() },
      }),
    );

    const access_token = this.jwt.sign(
      {
        sub: app.id,
        tenantId: app.tenantId,
        escopos: app.escopos,
        aud: OD_AUDIENCE,
      },
      { expiresIn: TOKEN_TTL_SEG },
    );
    return { access_token, token_type: 'Bearer', expires_in: TOKEN_TTL_SEG };
  }
}
