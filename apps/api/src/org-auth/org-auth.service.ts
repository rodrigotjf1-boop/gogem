import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { OrgUsuario } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { OrgLoginDto } from './dto/org-login.dto';
import { OrgJwtPayload } from './org-jwt.strategy';

/** OrgUsuario sem o hash (o que sai na resposta). */
export type OrgUsuarioPublico = Omit<OrgUsuario, 'senhaHash'>;

export interface OrgAuthResult {
  access_token: string;
  user: OrgUsuarioPublico;
}

/**
 * OrgAuthService — login do Console da Distribuição (usuário da organização).
 * `OrgUsuario` é cross-tenant (fora do TENANT_SCOPED_MODELS), então as queries
 * rodam sem contexto de tenant — sem `runAsSystem`. NÃO há cadastro público: o
 * 1º admin da org entra por seed (scripts/seed-org-admin).
 */
@Injectable()
export class OrgAuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async login(dto: OrgLoginDto): Promise<OrgAuthResult> {
    const user = await this.prisma.orgUsuario.findUnique({
      where: { email: dto.email },
    });
    const senhaOk =
      user && user.ativo && (await bcrypt.compare(dto.senha, user.senhaHash));
    if (!user || !senhaOk) {
      throw new UnauthorizedException('Credenciais inválidas.');
    }
    return this.emitir(user);
  }

  async porId(id: string): Promise<OrgUsuarioPublico | null> {
    const user = await this.prisma.orgUsuario.findUnique({ where: { id } });
    return user ? this.semHash(user) : null;
  }

  private emitir(user: OrgUsuario): OrgAuthResult {
    const payload: OrgJwtPayload = {
      sub: user.id,
      tipo: 'org',
      papel: user.papel,
      email: user.email,
    };
    return { access_token: this.jwt.sign(payload), user: this.semHash(user) };
  }

  private semHash(user: OrgUsuario): OrgUsuarioPublico {
    const copia = { ...user } as Partial<Pick<OrgUsuario, 'senhaHash'>> &
      OrgUsuarioPublico;
    delete copia.senhaHash;
    return copia;
  }
}
