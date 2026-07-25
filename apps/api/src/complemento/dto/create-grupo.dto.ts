import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Corpo de criação de um grupo de complementos (etapa) de um produto.
 * A coerência min/max (min ≥ 0; se `max` != null então `max` ≥ `min`) é
 * validada no service (regra de negócio), não só aqui.
 * `tenantId` e `produtoId` são resolvidos fora do corpo (§2 / rota aninhada).
 */
export class CreateGrupoDto {
  @ApiProperty({ description: 'Nome do grupo.', example: 'Escolha a bebida' })
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  nome!: string;

  @ApiProperty({
    description: 'Mínimo de opções a selecionar.',
    required: false,
    default: 0,
    example: 1,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  min?: number;

  @ApiProperty({
    description: 'Máximo de opções a selecionar (null/ausente = ilimitado).',
    required: false,
    example: 1,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  max?: number;

  @ApiProperty({
    description: 'Se o grupo é de preenchimento obrigatório.',
    required: false,
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  obrigatorio?: boolean;

  @ApiProperty({
    description: 'Ordem de exibição.',
    required: false,
    default: 0,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  ordem?: number;
}
