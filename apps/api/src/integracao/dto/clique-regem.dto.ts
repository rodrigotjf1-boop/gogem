import { IsOptional, IsString, MaxLength } from 'class-validator';

/** O que o Regem devolveu ao navegador na volta do "Conectar pelo Regem" (o painel repassa tal como veio). */
export class VoltaDoRegemDto {
  @IsOptional()
  @IsString()
  @MaxLength(400)
  code?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  state?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  iss?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  error?: string;
}

/** A loja do Regem em uso (uma das que o presidente ligou a esta empresa). */
export class LojaDoRegemDto {
  @IsString()
  @MaxLength(100)
  lojaId!: string;
}
