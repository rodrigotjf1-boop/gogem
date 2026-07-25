import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsInt, IsOptional, Min } from 'class-validator';

/**
 * Filtro do endpoint de leitura do catálogo publicado. `desde` é a versão que o
 * totem já possui: se for >= à última publicada, a API responde "atualizado:
 * false" sem corpo do snapshot (checagem barata de "estou em dia?").
 */
export class PublicadoQuery {
  @ApiPropertyOptional({
    description: 'Versão que o cliente já possui (checagem incremental).',
    type: Number,
    minimum: 1,
  })
  @IsOptional()
  @Transform(({ value }) =>
    value === undefined || value === '' ? undefined : Number(value),
  )
  @IsInt()
  @Min(1)
  desde?: number;
}
