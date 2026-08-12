import { IsOptional, IsString, MinLength } from 'class-validator';

/**
 * Publicação de um build Windows do totem (multipart: o .zip no campo `build`).
 * `versao` é livre (string), não versionCode.
 */
export class PublicarWindowsDto {
  @IsString()
  @MinLength(1)
  versao!: string;

  @IsOptional()
  @IsString()
  notas?: string;
}
