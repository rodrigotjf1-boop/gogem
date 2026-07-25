import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

/**
 * Corpo do login por e-mail + senha.
 */
export class LoginDto {
  @ApiProperty({ description: 'E-mail de login.', example: 'jose@bardoze.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ description: 'Senha.' })
  @IsString()
  @MinLength(8)
  senha!: string;
}
