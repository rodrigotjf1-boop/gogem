import { Module } from '@nestjs/common';
import { PagamentosController } from './pagamentos.controller';
import { PagamentosService } from './pagamentos.service';
import { PspResolver } from './psp/psp-resolver';

/**
 * PagamentosModule — PIX via PSP (F8). O gateway é escolhido POR LOJA pelo
 * `PspResolver` (lê a integração `mercadopago` do tenant, configurada no admin).
 * Sem config, cai no fallback de ambiente (`GOGEM_PSP`/`MERCADOPAGO_ACCESS_TOKEN`)
 * e, na ausência de tudo, no sandbox (QR de teste que aprova sozinho).
 */
@Module({
  controllers: [PagamentosController],
  providers: [PagamentosService, PspResolver],
})
export class PagamentosModule {}
