import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/jwt.strategy';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { MidiaService } from './midia.service';

/** Arquivo enviado (subset do Express.Multer.File — evita o @types/multer). */
interface ArquivoEnviado {
  buffer: Buffer;
  mimetype: string;
  size: number;
}

const TIPOS: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};
const MAX_BYTES = 5 * 1024 * 1024; // 5 MB

/**
 * Upload de imagem (foto de produto, mídia). Gerente+ (JWT). O arquivo vai no
 * campo multipart `arquivo`. Retorna `{ url }` pública (Supabase Storage).
 */
@ApiTags('midia')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('gerente')
@Controller('midia')
export class MidiaController {
  constructor(private readonly midia: MidiaService) {}

  @Post()
  @UseInterceptors(FileInterceptor('arquivo'))
  @ApiOkResponse({ description: 'Imagem enviada; retorna a URL pública.' })
  async upload(
    @CurrentUser() user: AuthenticatedUser,
    @UploadedFile() arquivo?: ArquivoEnviado,
  ): Promise<{ url: string }> {
    if (!arquivo) {
      throw new BadRequestException('Envie a imagem no campo "arquivo".');
    }
    const ext = TIPOS[arquivo.mimetype];
    if (!ext) {
      throw new BadRequestException(
        'Formato inválido: use JPG, PNG, WEBP ou GIF.',
      );
    }
    if (arquivo.size > MAX_BYTES) {
      throw new BadRequestException('Imagem muito grande (máximo 5 MB).');
    }
    const url = await this.midia.upload(
      user.tenantId,
      arquivo.buffer,
      arquivo.mimetype,
      ext,
    );
    return { url };
  }
}
