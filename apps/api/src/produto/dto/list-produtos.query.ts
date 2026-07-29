import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsOptional, IsUUID } from 'class-validator';

/**
 * Filtros da listagem de produtos. Query params chegam como string; `disponivel`
 * é normalizado para boolean.
 */
export class ListProdutosQuery {
  @ApiPropertyOptional({ description: 'Cardápio (Fase 3B). Ausente = ativo.' })
  @IsOptional()
  @IsUUID()
  cardapioId?: string;

  @ApiPropertyOptional({ description: 'Filtra por categoria.' })
  @IsOptional()
  @IsUUID()
  categoriaId?: string;

  @ApiPropertyOptional({
    description: 'Filtra por disponibilidade.',
    type: Boolean,
  })
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true) return true;
    if (value === 'false' || value === false) return false;
    return value;
  })
  @IsBoolean()
  disponivel?: boolean;
}
