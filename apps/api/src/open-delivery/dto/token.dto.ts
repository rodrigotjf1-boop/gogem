import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MinLength } from 'class-validator';

/** Corpo do grant `client_credentials` (OAuth2) do Open Delivery. */
export class OpenDeliveryTokenDto {
  @ApiProperty({ enum: ['client_credentials'] })
  @IsIn(['client_credentials'])
  grant_type!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  client_id!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  client_secret!: string;
}
