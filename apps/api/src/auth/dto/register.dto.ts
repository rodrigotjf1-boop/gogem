import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

/**
 * Corpo do cadastro inicial: cria a empresa (tenant) + o 1º usuário
 * (presidente). Ver AuthService.register.
 */
export class RegisterDto {
  @ApiProperty({
    description: 'Nome da empresa (tenant).',
    example: 'Bar do Zé',
  })
  @IsString()
  @MinLength(2)
  empresa!: string;

  @ApiProperty({ description: 'Nome do usuário presidente.', example: 'José' })
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiProperty({ description: 'E-mail de login.', example: 'jose@bardoze.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ description: 'Senha (mín. 8 caracteres).', minLength: 8 })
  @IsString()
  @MinLength(8)
  senha!: string;
}
