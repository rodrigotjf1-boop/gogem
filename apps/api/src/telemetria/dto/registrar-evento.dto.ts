import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Evento de telemetria que o totem sobe (erro/aviso/info). */
export class RegistrarEventoDto {
  @ApiPropertyOptional({ enum: ['erro', 'aviso', 'info'], default: 'erro' })
  @IsOptional()
  @IsIn(['erro', 'aviso', 'info'])
  nivel?: 'erro' | 'aviso' | 'info';

  @ApiProperty({ description: 'Resumo do evento/erro.' })
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  mensagem!: string;

  @ApiPropertyOptional({ description: 'Detalhe/stack (texto).' })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  detalhe?: string;

  @ApiPropertyOptional({ description: 'Versão do app do totem.' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  appVersao?: string;
}
