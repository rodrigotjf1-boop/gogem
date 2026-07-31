import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Escopos concedíveis a um app Open Delivery. */
export const OD_ESCOPOS = [
  'catalog:read',
  'orders:read',
  'orders:write',
] as const;

/** Cadastro de um app parceiro (o clientSecret é gerado e mostrado UMA vez). */
export class CreateOpenDeliveryAppDto {
  @ApiProperty({ description: 'Nome do parceiro/integração.' })
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  nome!: string;

  @ApiPropertyOptional({
    description: 'Escopos concedidos. Padrão: catalog:read + orders:write.',
    enum: OD_ESCOPOS,
    isArray: true,
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsIn(OD_ESCOPOS, { each: true })
  escopos?: string[];
}
