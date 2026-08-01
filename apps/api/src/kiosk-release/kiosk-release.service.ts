import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MidiaService } from '../midia/midia.service';
import { PublicarReleaseDto } from './dto/publicar-release.dto';

/** APK enviado (subset do Multer — evita @types/multer). */
export interface ApkEnviado {
  buffer: Buffer;
  mimetype: string;
  size: number;
}

const MAX_APK = 150 * 1024 * 1024; // 150 MB

/**
 * KioskReleaseService — releases do APK do totem (auto-update). GLOBAL: o modelo
 * KioskRelease NÃO é tenant-scoped (não está em TENANT_SCOPED_MODELS), então as
 * queries rodam sem contexto de tenant — o APK é o mesmo para todas as lojas.
 */
@Injectable()
export class KioskReleaseService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly midia: MidiaService,
  ) {}

  /** Manifesto que o totem consome: a release ATIVA de maior versionCode. */
  async latest() {
    const r = await this.prisma.kioskRelease.findFirst({
      where: { ativo: true },
      orderBy: { versionCode: 'desc' },
    });
    if (!r) return null;
    return {
      versionCode: r.versionCode,
      versionName: r.versionName,
      apkUrl: r.apkUrl,
      sha256: r.sha256,
      notas: r.notas,
      obrigatorio: r.obrigatorio,
    };
  }

  /** Histórico de releases (mais nova primeiro) — para o painel do DMS. */
  async lista() {
    return this.prisma.kioskRelease.findMany({
      orderBy: { versionCode: 'desc' },
    });
  }

  /**
   * Publica (ou re-publica) uma release: sobe o APK no storage, calcula o sha256
   * e grava/atualiza a linha por `versionCode`, deixando-a ativa.
   */
  async publicar(dto: PublicarReleaseDto, apk?: ApkEnviado) {
    if (!apk) throw new BadRequestException('Envie o APK no campo "apk".');
    if (apk.size > MAX_APK) {
      throw new BadRequestException('APK muito grande (máximo 150 MB).');
    }
    // APK é um ZIP: começa com a assinatura "PK" (0x50 0x4B).
    if (!(apk.buffer[0] === 0x50 && apk.buffer[1] === 0x4b)) {
      throw new BadRequestException('Arquivo não parece um APK (.apk) válido.');
    }

    const sha256 = createHash('sha256').update(apk.buffer).digest('hex');
    const key = `kiosk/releases/${dto.versionCode}-${randomUUID()}.apk`;
    const apkUrl = await this.midia.uploadBinario(
      key,
      apk.buffer,
      'application/vnd.android.package-archive',
    );

    return this.prisma.kioskRelease.upsert({
      where: { versionCode: dto.versionCode },
      create: {
        versionCode: dto.versionCode,
        versionName: dto.versionName,
        apkUrl,
        sha256,
        notas: dto.notas ?? null,
        obrigatorio: dto.obrigatorio ?? false,
        ativo: true,
      },
      update: {
        versionName: dto.versionName,
        apkUrl,
        sha256,
        notas: dto.notas ?? null,
        obrigatorio: dto.obrigatorio ?? false,
        ativo: true,
      },
    });
  }
}
