import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

/**
 * Item da venda de totem — casado no Regem por `codigoPdv` (de-para §4, NUNCA
 * id interno). `quantidade` é inteiro positivo.
 */
export class VendaTotemItemDto {
  @ApiProperty({ description: 'Código PDV do produto (de-para Regem §4).' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  codigoPdv!: string;

  @ApiProperty({ description: 'Quantidade (inteiro ≥ 1).', example: 1 })
  @IsInt()
  @Min(1)
  quantidade!: number;

  @ApiPropertyOptional({ description: 'Observação da linha.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacao?: string;
}

/**
 * Forma de pagamento (split). `valor` em CENTAVOS inteiros (CLAUDE.md — dinheiro
 * sem float). `nsu`/`autorizacao` vêm do TEF quando cartão.
 */
export class VendaTotemPagamentoDto {
  @ApiProperty({ description: 'Forma de pagamento.', example: 'cartao' })
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  forma!: string;

  @ApiProperty({ description: 'Valor em centavos inteiros.', example: 2990 })
  @IsInt()
  @Min(0)
  valor!: number;

  @ApiPropertyOptional({ description: 'NSU do TEF (cartão).' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  nsu?: string;

  @ApiPropertyOptional({ description: 'Código de autorização do TEF.' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  autorizacao?: string;

  @ApiPropertyOptional({ description: 'ID da forma de pagamento no Regem.' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  formaPagamentoId?: string;
}

/**
 * Corpo da venda de totem (issue #12.2). O totem manda ao GoGeM; o GoGeM repassa
 * ao Regem. `idempotencyKey` é gerada no totem (offline-first §1) e é a chave da
 * idempotência dupla. `tenantId` NÃO entra — vem do dispositivo autenticado.
 */
export class VendaTotemDto {
  @ApiProperty({
    description: 'Chave de idempotência gerada no totem (UUID).',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  idempotencyKey!: string;

  @ApiProperty({
    description: 'Itens da venda (≥ 1), casados por codigoPdv.',
    type: [VendaTotemItemDto],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => VendaTotemItemDto)
  itens!: VendaTotemItemDto[];

  @ApiProperty({
    description: 'Pagamentos (≥ 1), split por forma; valor em centavos.',
    type: [VendaTotemPagamentoDto],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => VendaTotemPagamentoDto)
  pagamentos!: VendaTotemPagamentoDto[];

  @ApiPropertyOptional({ description: 'CPF na nota (opcional).' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  cpf?: string;

  @ApiPropertyOptional({ description: 'Nome informado no totem (opcional).' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  cliente?: string;

  @ApiPropertyOptional({
    description: 'Tipo de consumo: local (comer aqui) ou viagem.',
    enum: ['local', 'viagem'],
    default: 'local',
  })
  @IsOptional()
  @IsIn(['local', 'viagem'])
  consumo?: 'local' | 'viagem';

  @ApiPropertyOptional({
    description: 'Percentual de taxa de serviço (inteiro), ex.: 10 = 10%.',
    example: 10,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  taxaServicoPct?: number;

  @ApiPropertyOptional({
    description:
      'Senha local exibida no totem (repassada como senhaPlataforma).',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  senhaLocal?: number;
}
