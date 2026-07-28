import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ExternalRefDto } from './external-ref.dto';

/**
 * Corpo de criação de produto. Preço em centavos (inteiro) — nunca float
 * (CLAUDE.md; a conversão para reais/decimal ocorre no import do Regem).
 * `tenantId` é injetado pelo middleware do Prisma (§2), não vem no corpo.
 */
export class CreateProdutoDto {
  @ApiProperty({ description: 'Nome do produto.', example: 'X-Salada' })
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  nome!: string;

  @ApiProperty({
    description: 'Descrição do produto.',
    required: false,
    example: 'Pão, hambúrguer, salada e queijo.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  descricao?: string;

  @ApiProperty({
    description: 'Preço em centavos (inteiro, nunca float).',
    example: 2590,
  })
  @IsInt()
  @Min(0)
  precoCentavos!: number;

  @ApiProperty({
    description: 'Disponível para venda.',
    required: false,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  disponivel?: boolean;

  @ApiProperty({
    description: 'URL pública da foto do produto (Supabase Storage).',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  imagemUrl?: string;

  @ApiProperty({
    description: 'Categoria à qual o produto pertence (opcional).',
    required: false,
  })
  @IsOptional()
  @IsUUID()
  categoriaId?: string;

  @ApiProperty({
    description: 'De-para PDV (§4): array de { sistema, codigo_pdv, loja? }.',
    required: false,
    type: [ExternalRefDto],
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ExternalRefDto)
  externalRefs?: ExternalRefDto[];
}
