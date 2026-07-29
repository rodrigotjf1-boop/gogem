import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsISO8601, IsOptional } from 'class-validator';

/** Filtro de período (ISO 8601) para os relatórios. */
export class RelatorioPeriodoDto {
  @ApiPropertyOptional({ description: 'Início do período (ISO 8601).' })
  @IsOptional()
  @IsISO8601()
  de?: string;

  @ApiPropertyOptional({ description: 'Fim do período (ISO 8601).' })
  @IsOptional()
  @IsISO8601()
  ate?: string;
}

/** Filtro de pedidos: período + status opcional. */
export class RelatorioPedidosDto extends RelatorioPeriodoDto {
  @ApiPropertyOptional({
    description: 'Status do pedido.',
    enum: ['pendente', 'enviado', 'falha', 'cancelado'],
  })
  @IsOptional()
  @IsIn(['pendente', 'enviado', 'falha', 'cancelado'])
  status?: string;
}
