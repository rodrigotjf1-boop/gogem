import {
  Controller,
  Get,
  HttpCode,
  NotFoundException,
  Post,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { OrgLoginDto } from './dto/org-login.dto';
import { OrgAuthGuard } from './org-auth.guard';
import { OrgAuthService } from './org-auth.service';
import type { OrgAuthUser } from './org-jwt.strategy';

/**
 * Console da Distribuição — autenticação da ORGANIZAÇÃO (DMS), separada do
 * login do cliente. Base `/org`.
 */
@ApiTags('org')
@Controller('org')
export class OrgAuthController {
  constructor(private readonly service: OrgAuthService) {}

  @Post('auth/login')
  @HttpCode(200)
  login(@Body() dto: OrgLoginDto) {
    return this.service.login(dto);
  }

  @Get('me')
  @UseGuards(OrgAuthGuard)
  async me(@Req() req: { user?: OrgAuthUser }) {
    const u = req.user as OrgAuthUser;
    const user = await this.service.porId(u.orgUserId);
    if (!user)
      throw new NotFoundException('Usuário da organização não encontrado.');
    return user;
  }
}
