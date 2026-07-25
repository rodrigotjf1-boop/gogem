import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Usuario } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtPayload } from './jwt.strategy';

const BCRYPT_ROUNDS = 10;

/** Usuário sem o hash da senha (o que sai na resposta / vai pro token). */
export type UsuarioPublico = Omit<Usuario, 'senhaHash'>;

export interface AuthResult {
  access_token: string;
  user: UsuarioPublico;
}

/**
 * AuthService — cadastro, login e emissão de JWT (espelha o Regem).
 *
 * register/login rodam sob `TenantContext.runAsSystem`: são operações de
 * bootstrap que precedem o contexto de tenant (register cria o 1º tenant;
 * login busca o usuário por e-mail globalmente). Por isso o `tenantId` é
 * sempre fornecido à mão nos dados/where — o escape hatch não relaxa o
 * isolamento, apenas dispensa a exigência de contexto.
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResult> {
    const senhaHash = await bcrypt.hash(dto.senha, BCRYPT_ROUNDS);

    const usuario = await TenantContext.runAsSystem(async () => {
      const tenant = await this.prisma.tenant.create({
        data: { nome: dto.empresa },
      });
      // tenantId explícito: create de modelo escopado dentro do escape hatch.
      return this.prisma.usuario.create({
        data: {
          tenantId: tenant.id,
          nome: dto.nome,
          email: dto.email,
          senhaHash,
          papel: 'presidente',
        },
      });
    });

    return this.emitir(usuario);
  }

  async login(dto: LoginDto): Promise<AuthResult> {
    // Busca global por e-mail (login ainda não tem tenant no contexto).
    const usuario = await TenantContext.runAsSystem(() =>
      this.prisma.usuario.findFirst({ where: { email: dto.email } }),
    );

    const senhaOk =
      usuario && (await bcrypt.compare(dto.senha, usuario.senhaHash));
    if (!usuario || !senhaOk) {
      // Mensagem genérica: não revela se o e-mail existe.
      throw new UnauthorizedException('Credenciais inválidas.');
    }

    return this.emitir(usuario);
  }

  /** Assina o JWT e devolve o usuário sem o hash. */
  private emitir(usuario: Usuario): AuthResult {
    const payload: JwtPayload = {
      sub: usuario.id,
      tenant: usuario.tenantId,
      papel: usuario.papel,
      email: usuario.email,
    };
    // Remove o hash antes de expor o usuário.
    const user = { ...usuario } as Partial<Pick<Usuario, 'senhaHash'>> &
      UsuarioPublico;
    delete user.senhaHash;
    return { access_token: this.jwt.sign(payload), user };
  }
}
