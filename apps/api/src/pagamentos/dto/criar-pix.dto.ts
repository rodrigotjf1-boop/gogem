import { IsInt, IsOptional, IsString, Min, MinLength } from 'class-validator';

/** Criação de cobrança PIX pelo totem. Valor em centavos; orderId = UUID do pedido. */
export class CriarPixDto {
  @IsInt()
  @Min(1)
  amountCents!: number;

  @IsString()
  @MinLength(1)
  orderId!: string;

  @IsOptional()
  @IsString()
  descricao?: string;

  @IsOptional()
  @IsString()
  cpfCnpj?: string;
}
