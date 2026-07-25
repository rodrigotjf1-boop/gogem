import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ExternalRefDto } from '../../produto/dto/external-ref.dto';

/**
 * Corpo de criação de uma opção de um grupo de complementos.
 * `precoCentavosDelta` é um delta em centavos (inteiro, nunca float) sobre o
 * preço-base do produto — pode ser negativo (desconto). Uma opção sem ref com
 * `codigo_pdv` é "informativa" (espelha o Regem): array vazio é permitido.
 * `tenantId` e `grupoId` são resolvidos fora do corpo (§2 / rota aninhada).
 */
export class CreateOpcaoDto {
  @ApiProperty({ description: 'Nome da opção.', example: 'Coca-Cola lata' })
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  nome!: string;

  @ApiProperty({
    description: 'Delta de preço em centavos (inteiro; pode ser negativo).',
    required: false,
    default: 0,
    example: 500,
  })
  @IsOptional()
  @IsInt()
  precoCentavosDelta?: number;

  @ApiProperty({
    description: 'Disponível para seleção.',
    required: false,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  disponivel?: boolean;

  @ApiProperty({
    description: 'Ordem de exibição.',
    required: false,
    default: 0,
  })
  @IsOptional()
  @IsInt()
  ordem?: number;

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
