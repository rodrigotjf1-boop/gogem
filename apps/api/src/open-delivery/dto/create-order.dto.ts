import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

/** Valor monetário Open Delivery (reais decimais). */
export class ODMoneyDto {
  @ApiProperty()
  @IsNumber()
  @Min(0)
  value!: number;

  @ApiPropertyOptional({ default: 'BRL' })
  @IsOptional()
  @IsString()
  currency?: string;
}

export class ODOrderItemOptionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  externalCode?: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  name!: string;

  @ApiProperty()
  @IsNumber()
  @Min(1)
  quantity!: number;

  @ApiProperty({ type: ODMoneyDto })
  @ValidateNested()
  @Type(() => ODMoneyDto)
  price!: ODMoneyDto;
}

export class ODOrderItemDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  externalCode?: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  name!: string;

  @ApiProperty()
  @IsNumber()
  @Min(1)
  quantity!: number;

  @ApiProperty({ type: ODMoneyDto })
  @ValidateNested()
  @Type(() => ODMoneyDto)
  price!: ODMoneyDto;

  @ApiPropertyOptional({ type: [ODOrderItemOptionDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ODOrderItemOptionDto)
  options?: ODOrderItemOptionDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observations?: string;
}

export class ODOrderPaymentDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  method!: string;

  @ApiProperty({ type: ODMoneyDto })
  @ValidateNested()
  @Type(() => ODMoneyDto)
  value!: ODMoneyDto;
}

export class ODOrderCustomerDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40)
  document?: string;
}

/** Ingest de um pedido Open Delivery (parceiro → GoGeM). */
export class CreateOpenDeliveryOrderDto {
  @ApiProperty({ description: 'ID do pedido no parceiro (idempotência).' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  displayId!: string;

  @ApiPropertyOptional({ type: ODOrderCustomerDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ODOrderCustomerDto)
  customer?: ODOrderCustomerDto;

  @ApiProperty({ type: [ODOrderItemDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ODOrderItemDto)
  items!: ODOrderItemDto[];

  @ApiProperty({ type: [ODOrderPaymentDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ODOrderPaymentDto)
  payments!: ODOrderPaymentDto[];

  @ApiProperty({ type: ODMoneyDto })
  @ValidateNested()
  @Type(() => ODMoneyDto)
  total!: ODMoneyDto;
}
