import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';

/**
 * Corpo do pareamento público: o totem troca o `codigo` de 6 dígitos por um
 * token de dispositivo. Validação estrita de formato; a validade de negócio
 * (existe / não expirou / ativo / não pareado) é conferida no service.
 */
export class ParearDto {
  @ApiProperty({
    description: 'Código de pareamento de 6 dígitos.',
    example: '123456',
  })
  @IsString()
  @Length(6, 6)
  codigo!: string;
}
