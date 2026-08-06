import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

/** Cria uma cobrança de cartão na Point Smart. Valor em centavos. */
export class CriarPointDto {
  @IsInt()
  @Min(1)
  amountCents!: number;

  @IsString()
  @MinLength(1)
  orderId!: string;

  @IsOptional()
  @IsIn(['credit', 'debit'])
  tipo?: string;
}
