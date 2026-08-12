import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MidiaService } from '../midia/midia.service';
import { PublicarReleaseDto } from './dto/publicar-release.dto';
import { PublicarWindowsDto } from './dto/publicar-windows.dto';

/** Arquivo enviado (subset do Multer — evita @types/multer). */
export interface ApkEnviado {
  buffer: Buffer;
  mimetype: string;
  size: number;
}

const MAX_APK = 150 * 1024 * 1024; // 150 MB
const MAX_WIN = 300 * 1024 * 1024; // 300 MB (pasta Release + DLLs)

/** Todo arquivo .apk/.zip começa com a assinatura "PK" (0x50 0x4B). */
function ehZip(buf: Buffer): boolean {
  return buf[0] === 0x50 && buf[1] === 0x4b;
}

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

  // ── Windows (só download; sem auto-update) ─────────────────────────────────

  /** Builds Windows (mais novo primeiro) — para o painel da Distribuição. */
  async listaWindows() {
    return this.prisma.windowsBuild.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Publica (ou re-publica por `versao`) um build Windows (.zip). */
  async publicarWindows(dto: PublicarWindowsDto, build?: ApkEnviado) {
    if (!build) throw new BadRequestException('Envie o .zip no campo "build".');
    if (build.size > MAX_WIN) {
      throw new BadRequestException('Build muito grande (máximo 300 MB).');
    }
    if (!ehZip(build.buffer)) {
      throw new BadRequestException('Arquivo não parece um .zip válido.');
    }
    const sha256 = createHash('sha256').update(build.buffer).digest('hex');
    const key = `kiosk/windows/${dto.versao}-${randomUUID()}.zip`;
    const url = await this.midia.uploadBinario(
      key,
      build.buffer,
      'application/zip',
    );

    return this.prisma.windowsBuild.upsert({
      where: { versao: dto.versao },
      create: {
        versao: dto.versao,
        url,
        sha256,
        notas: dto.notas ?? null,
        ativo: true,
      },
      update: { url, sha256, notas: dto.notas ?? null, ativo: true },
    });
  }
}
