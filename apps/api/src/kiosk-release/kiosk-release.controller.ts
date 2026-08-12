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
import { OrgAuthGuard } from '../org-auth/org-auth.guard';
import { ApkEnviado, KioskReleaseService } from './kiosk-release.service';
import { PublicarReleaseDto } from './dto/publicar-release.dto';
import { PublicarWindowsDto } from './dto/publicar-windows.dto';

/**
 * Releases do APK do totem (auto-update).
 *
 * - `GET /kiosk/latest` — o totem (X-Device-Token) baixa o manifesto e decide se
 *   atualiza (compara versionCode, confere sha256).
 * - `GET/POST /kiosk/releases` — publicação/histórico, restrito à ORGANIZAÇÃO
 *   (Console da Distribuição, `OrgAuthGuard`). Não exposto ao lojista. Antes era
 *   um token colado (KIOSK_RELEASE_TOKEN); agora exige login da org.
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
  @UseGuards(OrgAuthGuard)
  lista() {
    return this.service.lista();
  }

  @Post('releases')
  @UseGuards(OrgAuthGuard)
  @UseInterceptors(FileInterceptor('apk'))
  publicar(@Body() dto: PublicarReleaseDto, @UploadedFile() apk?: ApkEnviado) {
    return this.service.publicar(dto, apk);
  }

  // ── Windows (só download; sem auto-update) — org-only ──────────────────────

  @Get('windows')
  @UseGuards(OrgAuthGuard)
  listaWindows() {
    return this.service.listaWindows();
  }

  @Post('windows')
  @UseGuards(OrgAuthGuard)
  @UseInterceptors(FileInterceptor('build'))
  publicarWindows(
    @Body() dto: PublicarWindowsDto,
    @UploadedFile() build?: ApkEnviado,
  ) {
    return this.service.publicarWindows(dto, build);
  }
}
