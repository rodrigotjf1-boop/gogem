import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { randomUUID } from 'node:crypto';

/**
 * MidiaService — upload de imagens para o Storage (S3-compatível: Supabase).
 *
 * Config por env (setar no EasyPanel): S3_ENDPOINT, S3_REGION, S3_ACCESS_KEY,
 * S3_SECRET_KEY, S3_BUCKET. A URL pública é derivada do endpoint do Supabase
 * (`.../storage/v1/object/public/<bucket>/<key>`). Sem config, o upload falha
 * com 400 explicando o que falta (o resto da API funciona normal).
 */
@Injectable()
export class MidiaService {
  private readonly s3: S3Client | null;
  private readonly bucket: string;
  private readonly publicBase: string;

  constructor(config: ConfigService) {
    const endpoint = config.get<string>('S3_ENDPOINT');
    const region = config.get<string>('S3_REGION') ?? 'us-east-1';
    const accessKeyId = config.get<string>('S3_ACCESS_KEY');
    const secretAccessKey = config.get<string>('S3_SECRET_KEY');
    this.bucket = config.get<string>('S3_BUCKET') ?? '';
    // Supabase: endpoint = https://<ref>.supabase.co/storage/v1/s3
    this.publicBase = endpoint
      ? endpoint.replace(/\/storage\/v1\/s3\/?$/, '')
      : '';
    this.s3 =
      endpoint && accessKeyId && secretAccessKey
        ? new S3Client({
            endpoint,
            region,
            forcePathStyle: true,
            credentials: { accessKeyId, secretAccessKey },
          })
        : null;
  }

  /** Sobe um arquivo e devolve a URL pública. Escopo por tenant no caminho. */
  async upload(
    tenantId: string,
    buffer: Buffer,
    contentType: string,
    ext: string,
  ): Promise<string> {
    if (!this.s3 || !this.bucket) {
      throw new BadRequestException(
        'Storage de mídia não configurado: defina S3_ENDPOINT, S3_REGION, ' +
          'S3_ACCESS_KEY, S3_SECRET_KEY e S3_BUCKET no ambiente da API.',
      );
    }
    const key = `${tenantId}/produtos/${randomUUID()}${ext}`;
    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );
    return `${this.publicBase}/storage/v1/object/public/${this.bucket}/${key}`;
  }

  /**
   * Sobe um binário arbitrário (ex.: APK do totem) numa chave dada e devolve a
   * URL pública. Usado pela publicação de release do totem (auto-update).
   */
  async uploadBinario(
    key: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<string> {
    if (!this.s3 || !this.bucket) {
      throw new BadRequestException(
        'Storage de mídia não configurado: defina S3_ENDPOINT, S3_REGION, ' +
          'S3_ACCESS_KEY, S3_SECRET_KEY e S3_BUCKET no ambiente da API.',
      );
    }
    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );
    return `${this.publicBase}/storage/v1/object/public/${this.bucket}/${key}`;
  }
}
