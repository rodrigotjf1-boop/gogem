import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthResult, AuthService } from './auth.service';
import { CurrentUser } from './current-user.decorator';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { AuthenticatedUser } from './jwt.strategy';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** Cadastro inicial: cria empresa (tenant) + usuário presidente. */
  // Rate-limit apertado (10/min por IP): register cria tenant → anti-spam.
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('register')
  @ApiOkResponse({
    description: 'Empresa e presidente criados; retorna token.',
  })
  register(@Body() dto: RegisterDto): Promise<AuthResult> {
    return this.auth.register(dto);
  }

  /** Login por e-mail + senha. */
  // Rate-limit apertado (10/min por IP): anti brute-force de senha.
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('login')
  @ApiOkResponse({ description: 'Credenciais válidas; retorna token.' })
  login(@Body() dto: LoginDto): Promise<AuthResult> {
    return this.auth.login(dto);
  }

  /** Amostra protegida: prova o guard + o contexto de tenant fim a fim. */
  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOkResponse({ description: 'Usuário do token.' })
  me(@CurrentUser() user: AuthenticatedUser): AuthenticatedUser {
    return user;
  }
}
