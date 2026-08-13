import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CancelarPedidoDto } from './dto/cancelar-pedido.dto';
import {
  RelatorioPedidosDto,
  RelatorioPeriodoDto,
} from './dto/relatorio-query.dto';
import { RelatorioService } from './relatorio.service';

/**
 * Relatórios operacionais (Fase 7): pedidos, faturamento (resumo), ranking de
 * produtos e cancelamento. Somente gerente+ (RBAC no servidor). Período padrão
 * = mês corrente quando `de`/`ate` não vierem.
 */
@ApiTags('relatorios')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('gerente')
@Controller('relatorios')
export class RelatorioController {
  constructor(private readonly service: RelatorioService) {}

  @Get('pedidos')
  pedidos(@Query() q: RelatorioPedidosDto) {
    const { de, ate } = periodo(q);
    return this.service.pedidos(de, ate, q.status);
  }

  @Get('resumo')
  resumo() {
    return this.service.resumo(new Date());
  }

  @Get('produtos')
  produtos(@Query() q: RelatorioPeriodoDto) {
    const { de, ate } = periodo(q);
    return this.service.porProduto(de, ate);
  }

  @Get('pagamentos')
  pagamentos(@Query() q: RelatorioPeriodoDto) {
    const { de, ate } = periodo(q);
    return this.service.porPagamento(de, ate);
  }

  @Get('horarios')
  horarios(@Query() q: RelatorioPeriodoDto) {
    const { de, ate } = periodo(q);
    return this.service.porHorario(de, ate);
  }

  @Post('pedidos/:id/cancelar')
  cancelar(@Param('id') id: string, @Body() dto: CancelarPedidoDto) {
    return this.service.cancelar(id, dto.motivo, new Date());
  }
}

/** Resolve o intervalo: usa de/ate quando válidos, senão o mês corrente. */
function periodo(q: RelatorioPeriodoDto): { de: Date; ate: Date } {
  const agora = new Date();
  const de = q.de
    ? new Date(q.de)
    : new Date(agora.getFullYear(), agora.getMonth(), 1);
  const ate = q.ate ? new Date(q.ate) : agora;
  return { de, ate };
}
