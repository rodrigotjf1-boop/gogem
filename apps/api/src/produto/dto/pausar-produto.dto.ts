import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

/** Pausa/despausa um produto no totem (Fase 4). */
export class PausarProdutoDto {
  @ApiProperty({
    description: 'true = pausar (indisponível); false = despausar.',
  })
  @IsBoolean()
  pausado!: boolean;
}
