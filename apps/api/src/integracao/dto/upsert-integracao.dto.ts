import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/**
 * Upsert da configuração de uma integração. `config` é um mapa string→string
 * com as chaves do conector (validadas/whitelisted no service pelo `tipo`).
 * Campos-segredo em branco significam "manter o valor guardado".
 */
export class UpsertIntegracaoDto {
  @ApiPropertyOptional({ description: 'Rótulo amigável da integração.' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  nome?: string;

  @ApiPropertyOptional({ description: 'Ativa/desativa a integração.' })
  @IsOptional()
  @IsBoolean()
  ativo?: boolean;

  @ApiPropertyOptional({
    description: 'Configuração do conector (chaves conforme o tipo).',
    type: 'object',
    additionalProperties: { type: 'string' },
  })
  @IsOptional()
  @IsObject()
  config?: Record<string, string>;
}
