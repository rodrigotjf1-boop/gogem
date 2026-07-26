import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * Corpo de criação de dispositivo (totem). `tenantId` NÃO entra aqui — o
 * middleware do Prisma injeta o tenant do contexto (CLAUDE.md §2).
 */
export class CreateDispositivoDto {
  @ApiProperty({
    description: 'Nome do dispositivo.',
    example: 'Totem entrada',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  nome!: string;

  @ApiPropertyOptional({
    description: 'Tipo do dispositivo.',
    example: 'totem',
    default: 'totem',
  })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  tipo?: string;

  @ApiPropertyOptional({ description: 'Unidade (loja) do dispositivo.' })
  @IsOptional()
  @IsUUID()
  unidadeId?: string;
}
