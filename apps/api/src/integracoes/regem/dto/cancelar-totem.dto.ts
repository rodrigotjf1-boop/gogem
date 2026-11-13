import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { QUEM_CANCELOU, type QuemCancelou } from '../estorno-sem-aprovacao';

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

  @ApiPropertyOptional({
    enum: QUEM_CANCELOU,
    description:
      'Quem cancelou no Regem: `pessoa` (o gestor/atendente) ou `agente` (um agente de IA). Só o cancelamento de uma ' +
      'pessoa estorna sem aprovação aqui (Padrão DMS, F5-10); `agente` → 422 `regra-invalida`. Ausente: o Regem de ' +
      'antes desta versão — aceito como antes.',
  })
  @IsOptional()
  @IsIn(QUEM_CANCELOU)
  canceladoPor?: QuemCancelou;
}
