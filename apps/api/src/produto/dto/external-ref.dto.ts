import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';

/**
 * De-para PDV (CLAUDE.md §4): referência de um produto num sistema externo.
 * As chamadas ao Regem (venda, pausa) SEMPRE usam `codigo_pdv`; o `regem_id`
 * só mantém o vínculo quando o Regem troca o código, e quem o grava é o GoGeM.
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

  @ApiProperty({
    description:
      'Id do produto no Regem. Gravado pelo GoGeM a partir do catálogo do Regem; o valor enviado é ignorado (aceito só para o produto voltar como veio).',
    required: false,
  })
  @IsOptional()
  @IsString()
  regem_id?: string;
}
