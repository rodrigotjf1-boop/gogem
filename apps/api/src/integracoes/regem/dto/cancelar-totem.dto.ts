import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Corpo do cancelamento vindo do Regem (`POST /sync/regem/pedido-cancelado`).
 * Identifica o pedido por `idempotencyKey` (uuid do totem) ou, alternativamente,
 * pelo `regemComandaId`. Só cancelamento TOTAL.
 */
export class CancelarTotemDto {
  @ApiPropertyOptional({
    description: 'idempotencyKey do pedido (uuid do totem).',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  idempotencyKey?: string;

  @ApiPropertyOptional({
    description: 'id da comanda no Regem (alternativa à idempotencyKey).',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  regemComandaId?: string;

  @ApiPropertyOptional({ description: 'Motivo do cancelamento (opcional).' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  motivo?: string;
}
