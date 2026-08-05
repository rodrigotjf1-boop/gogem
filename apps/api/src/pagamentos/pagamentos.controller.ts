import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DeviceTokenGuard } from '../auth/device-token.guard';
import { CriarPixDto } from './dto/criar-pix.dto';
import { PagamentosService } from './pagamentos.service';

/**
 * Pagamentos PIX (F8). O totem cria a cobrança e faz polling do status; o PSP
 * confirma por webhook. O tenant vem do X-Device-Token (contexto multi-tenant);
 * o webhook é público (o PSP chama) e casa pelo pspRef.
 */
@ApiTags('pagamentos')
@Controller('pagamentos')
export class PagamentosController {
  constructor(private readonly service: PagamentosService) {}

  @Post('pix')
  @UseGuards(DeviceTokenGuard)
  criar(@Body() dto: CriarPixDto) {
    return this.service.criarPix(dto);
  }

  @Get('pix/:id')
  @UseGuards(DeviceTokenGuard)
  status(@Param('id') id: string) {
    return this.service.statusPix(id);
  }

  // Webhook do PSP — público (o PSP não manda X-Device-Token). Não confia no
  // corpo: só extrai a referência e re-consulta o status no PSP.
  @Post('pix/webhook')
  @HttpCode(200)
  webhook(@Body() body: unknown, @Query() query: Record<string, unknown>) {
    return this.service.webhook(body, query);
  }
}
