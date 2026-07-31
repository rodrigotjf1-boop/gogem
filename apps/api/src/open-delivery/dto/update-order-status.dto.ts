import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsIn, IsString } from 'class-validator';

/** Status alcançáveis por atualização do parceiro. */
export const OD_ORDER_STATUS = [
  'CONFIRMED',
  'PREPARING',
  'READY',
  'DISPATCHED',
  'CONCLUDED',
  'CANCELLED',
] as const;

export class UpdateOpenDeliveryOrderStatusDto {
  @ApiProperty({ enum: OD_ORDER_STATUS })
  @IsIn(OD_ORDER_STATUS)
  status!: string;
}

/** Corpo do acknowledgment de eventos. */
export class AckEventsDto {
  @ApiProperty({ type: [String], description: 'IDs de eventos a confirmar.' })
  @IsArray()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  ids!: string[];
}
