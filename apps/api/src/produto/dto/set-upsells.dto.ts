import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsString } from 'class-validator';

/**
 * Substitui (replace-all) a lista de upsells "Peça também" do produto. Ordem do
 * array = ordem de exibição. Limite defensivo para não estourar o checkout.
 */
export class SetUpsellsDto {
  @ApiProperty({
    description: 'IDs dos produtos sugeridos, na ordem de exibição.',
    type: [String],
  })
  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  sugeridoIds!: string[];
}
