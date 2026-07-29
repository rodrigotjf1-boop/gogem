import { ApiProperty } from '@nestjs/swagger';
import { IsInt, Min } from 'class-validator';

/** Nova posição (ordem) de uma etapa dentro de um produto. */
export class ReordenarDto {
  @ApiProperty({ description: 'Ordem (0 = primeira).', example: 0 })
  @IsInt()
  @Min(0)
  ordem!: number;
}
