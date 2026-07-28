import { Body, Controller, Post } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { DispositivoService } from './dispositivo.service';
import { ParearDto } from './dto/parear.dto';

/**
 * Pareamento público de dispositivo (SEM auth) — issue #12.1. O totem troca o
 * código de 6 dígitos por um token de dispositivo. O lookup é GLOBAL (via
 * `runAsSystem` no service) porque ainda não há contexto de tenant.
 */
@ApiTags('dispositivos')
@Controller('publico/dispositivos')
export class DispositivoPublicoController {
  constructor(private readonly dispositivos: DispositivoService) {}

  // Rate-limit apertado (10/min por IP): anti brute-force do código de 6 dígitos
  // (endpoint público, sem auth). Resolve o TODO(seg) do DispositivoService.
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('parear')
  @ApiOkResponse({
    description:
      'Troca o código de pareamento por um token de dispositivo (retornado UMA vez).',
  })
  parear(@Body() dto: ParearDto) {
    return this.dispositivos.parear(dto.codigo);
  }
}
