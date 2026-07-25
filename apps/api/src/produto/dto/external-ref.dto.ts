import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';

/**
 * De-para PDV (CLAUDE.md §4): referência de um produto num sistema externo.
 * A integração com o Regem SEMPRE usa `codigo_pdv`, nunca o id interno.
 * Chaves em snake_case porque é o contrato de fio persistido no Json.
 */
export class ExternalRefDto {
  @ApiProperty({ description: 'Sistema externo.', example: 'regem' })
  @IsString()
  @MinLength(1)
  sistema!: string;

  @ApiProperty({
    description: 'Código do produto no PDV externo.',
    example: 'PROD-001',
  })
  @IsString()
  @MinLength(1)
  codigo_pdv!: string;

  @ApiProperty({
    description: 'Loja/unidade no sistema externo (opcional).',
    required: false,
    example: 'loja-centro',
  })
  @IsOptional()
  @IsString()
  loja?: string;
}
