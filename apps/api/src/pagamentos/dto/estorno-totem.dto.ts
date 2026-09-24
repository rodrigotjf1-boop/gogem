import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { VendaTotemItemDto } from '../../vendas/dto/venda-totem.dto';

/**
 * Estorno pedido pelo totem, pelo `orderId` do pagamento (= uuid do pedido no totem).
 * Usado quando o pagamento foi aprovado mas a venda não se concluiu: a NFC-e não foi
 * emitida (`nao_emitida` do Regem) ou o cupom fiscal não imprimiu.
 */
export class EstornoTotemDto {
  @ApiProperty({
    description: 'uuid do pedido no totem (= orderId do pagamento).',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  orderId!: string;

  @ApiProperty({
    description: 'Motivo legível — vai para o relatório e para a auditoria.',
    example: 'NFC-e não emitida (rejeitada 778): NCM inexistente',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  motivo!: string;

  @ApiPropertyOptional({
    description: 'Etapa que falhou (rejeitada, sem_contingencia, impressao…).',
  })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  etapa?: string;

  @ApiPropertyOptional({
    description:
      'Senha do pedido (servidor da loja: compõe o registro do relatório).',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  senha?: number;

  @ApiPropertyOptional({
    description:
      'Itens do pedido (servidor da loja: compõe o registro do relatório).',
    type: [VendaTotemItemDto],
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => VendaTotemItemDto)
  itens?: VendaTotemItemDto[];
}
