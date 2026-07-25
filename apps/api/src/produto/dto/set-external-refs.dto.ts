import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsArray, ValidateNested } from 'class-validator';
import { ExternalRefDto } from './external-ref.dto';

/**
 * Corpo do PUT /produtos/:id/external-refs — substitui o de-para PDV inteiro
 * (espelha `PUT /v1/menu/items/{id}/external-refs` do roadmap).
 */
export class SetExternalRefsDto {
  @ApiProperty({
    description: 'Novo array de de-para PDV (substitui o anterior).',
    type: [ExternalRefDto],
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ExternalRefDto)
  externalRefs!: ExternalRefDto[];
}
