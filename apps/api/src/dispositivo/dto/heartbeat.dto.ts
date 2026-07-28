import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Estado reportado pelo totem no heartbeat. Todos os campos são opcionais — o
 * totem manda o que sabe. Guardado em `Dispositivo.ultimoStatus` (Json).
 */
export class HeartbeatDto {
  @ApiPropertyOptional({ description: 'Versão do catálogo em uso no totem.' })
  @IsOptional()
  @IsInt()
  @Min(0)
  versaoCatalogo?: number;

  @ApiPropertyOptional({ description: 'Itens na fila de reimpressão.' })
  @IsOptional()
  @IsInt()
  @Min(0)
  filaImpressao?: number;

  @ApiPropertyOptional({ description: 'Impressora pronta para venda?' })
  @IsOptional()
  @IsBoolean()
  impressoraOk?: boolean;

  @ApiPropertyOptional({ description: 'Papel acabando (near-end)?' })
  @IsOptional()
  @IsBoolean()
  papelAcabando?: boolean;

  @ApiPropertyOptional({ description: 'Versão do app do totem.' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  appVersao?: string;
}
