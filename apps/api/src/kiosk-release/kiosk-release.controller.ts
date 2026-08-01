import {
  Body,
  Controller,
  Get,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags } from '@nestjs/swagger';
import { DeviceTokenGuard } from '../auth/device-token.guard';
import { ReleaseTokenGuard } from '../auth/release-token.guard';
import { ApkEnviado, KioskReleaseService } from './kiosk-release.service';
import { PublicarReleaseDto } from './dto/publicar-release.dto';

/**
 * Releases do APK do totem (auto-update).
 *
 * - `GET /kiosk/latest` — o totem (X-Device-Token) baixa o manifesto e decide se
 *   atualiza (compara versionCode, confere sha256).
 * - `GET/POST /kiosk/releases` — publicação/histórico, restrito ao DMS por
 *   `X-Release-Token` (KIOSK_RELEASE_TOKEN). Não exposto ao lojista.
 */
@ApiTags('kiosk')
@Controller('kiosk')
export class KioskReleaseController {
  constructor(private readonly service: KioskReleaseService) {}

  @Get('latest')
  @UseGuards(DeviceTokenGuard)
  latest() {
    return this.service.latest();
  }

  @Get('releases')
  @UseGuards(ReleaseTokenGuard)
  lista() {
    return this.service.lista();
  }

  @Post('releases')
  @UseGuards(ReleaseTokenGuard)
  @UseInterceptors(FileInterceptor('apk'))
  publicar(@Body() dto: PublicarReleaseDto, @UploadedFile() apk?: ApkEnviado) {
    return this.service.publicar(dto, apk);
  }
}
