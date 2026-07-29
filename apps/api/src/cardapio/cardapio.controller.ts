import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CardapioService, type CardapioView } from './cardapio.service';
import { CreateCardapioDto } from './dto/create-cardapio.dto';
import { UpdateCardapioDto } from './dto/update-cardapio.dto';

/**
 * Cardápios (Fase 3B). Leitura: qualquer usuário autenticado. Escrita/ativação:
 * gerente+. Tudo no tenant do chamador (§2).
 */
@ApiTags('cardapios')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('cardapios')
export class CardapioController {
  constructor(private readonly service: CardapioService) {}

  @Get()
  list(): Promise<CardapioView[]> {
    return this.service.list();
  }

  @Post()
  @Roles('gerente')
  create(@Body() dto: CreateCardapioDto): Promise<CardapioView> {
    return this.service.create(dto);
  }

  @Patch(':id')
  @Roles('gerente')
  rename(
    @Param('id') id: string,
    @Body() dto: UpdateCardapioDto,
  ): Promise<CardapioView> {
    return this.service.rename(id, dto);
  }

  @Post(':id/ativar')
  @Roles('gerente')
  ativar(@Param('id') id: string): Promise<CardapioView> {
    return this.service.ativar(id);
  }

  @Delete(':id')
  @Roles('gerente')
  remove(@Param('id') id: string): Promise<{ id: string }> {
    return this.service.remove(id);
  }
}
