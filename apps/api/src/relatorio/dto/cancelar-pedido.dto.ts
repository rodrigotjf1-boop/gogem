import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';

/** Motivo do cancelamento (falta de saldo / instabilidade bancária / etc.). */
export class CancelarPedidoDto {
  @ApiProperty({ description: 'Motivo do cancelamento.' })
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  motivo!: string;
}
