import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

/** Login do Console da Distribuição (usuário da organização/DMS). */
export class OrgLoginDto {
  @ApiProperty({ example: 'dms@gogem.com.br' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: '••••••••' })
  @IsString()
  @MinLength(1)
  senha!: string;
}
