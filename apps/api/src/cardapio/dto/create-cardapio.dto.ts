import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * Criação de um cardápio (Fase 3B). Nasce SEMPRE inativo (o ativo só muda por
 * "ativar"). `modo` define o conteúdo inicial:
 *  - `vazio` (padrão): estrutura zerada.
 *  - `duplicar`: cópia profunda do cardápio ATIVO (categorias/produtos/
 *    complementos/opções) — para preparar migração de sistema ou testes.
 */
export class CreateCardapioDto {
  @ApiProperty({
    description: 'Nome do cardápio.',
    example: 'Cardápio novo sistema',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  nome!: string;

  @ApiPropertyOptional({
    description: 'Conteúdo inicial: vazio ou duplicar o ativo.',
    enum: ['vazio', 'duplicar'],
    default: 'vazio',
  })
  @IsOptional()
  @IsIn(['vazio', 'duplicar'])
  modo?: 'vazio' | 'duplicar';
}
