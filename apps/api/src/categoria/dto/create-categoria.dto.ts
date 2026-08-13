import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Corpo de criação de categoria. `tenantId` NÃO entra aqui — o middleware do
 * Prisma injeta o tenant do contexto (CLAUDE.md §2).
 */
export class CreateCategoriaDto {
  @ApiProperty({ description: 'Nome da categoria.', example: 'Bebidas' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  nome!: string;

  @ApiProperty({
    description: 'Ordem de exibição (menor primeiro).',
    example: 0,
    required: false,
    default: 0,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  ordem?: number;

  @ApiProperty({
    description: 'Cardápio-alvo (Fase 3B). Ausente = cardápio ativo.',
    required: false,
  })
  @IsOptional()
  @IsUUID()
  cardapioId?: string;

  @ApiProperty({
    description: 'URL pública da imagem da categoria (roleta do totem).',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  imagemUrl?: string;

  @ApiProperty({
    description: 'Emoji da categoria (fallback quando não há imagem).',
    example: '🍔',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  emoji?: string;

  @ApiProperty({
    description: 'Cor de destaque da categoria (hex, ex.: "#E03A2F").',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(9)
  cor?: string;

  @ApiProperty({
    description: 'Pausar a categoria (some do totem, ela e seus produtos).',
    required: false,
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  pausada?: boolean;
}
