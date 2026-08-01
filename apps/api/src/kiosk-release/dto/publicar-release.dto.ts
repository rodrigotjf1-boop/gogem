import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Publicação de uma release do APK do totem. Vem por multipart (o APK no campo
 * `apk`), então os campos chegam como string — daí os @Type/@Transform.
 */
export class PublicarReleaseDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  versionCode!: number;

  @IsString()
  @MinLength(1)
  versionName!: string;

  @IsOptional()
  @IsString()
  notas?: string;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true' || value === '1')
  @IsBoolean()
  obrigatorio?: boolean;
}
