import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';

/** Renomeia um cardápio. */
export class UpdateCardapioDto {
  @ApiProperty({ description: 'Novo nome do cardápio.' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  nome!: string;
}
