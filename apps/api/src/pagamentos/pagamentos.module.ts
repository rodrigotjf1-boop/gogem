import { Module } from '@nestjs/common';
import { PagamentosController } from './pagamentos.controller';
import { PagamentosService } from './pagamentos.service';
import { PSP_GATEWAY, PspGateway } from './psp/psp-gateway';
import { SandboxPspGateway } from './psp/sandbox-psp.gateway';
import { MercadoPagoPspGateway } from './psp/mercadopago-psp.gateway';

/**
 * PagamentosModule — PIX via PSP (F8). O adaptador ativo vem de `GOGEM_PSP`
 * (default `sandbox`, testável sem credencial). `mercadopago` exige
 * `MERCADOPAGO_ACCESS_TOKEN` no ambiente (nunca no app).
 */
@Module({
  controllers: [PagamentosController],
  providers: [
    PagamentosService,
    {
      provide: PSP_GATEWAY,
      useFactory: (): PspGateway => {
        const psp = (process.env.GOGEM_PSP ?? 'sandbox').toLowerCase();
        if (psp === 'mercadopago') {
          const token = process.env.MERCADOPAGO_ACCESS_TOKEN;
          if (!token) {
            throw new Error(
              'GOGEM_PSP=mercadopago mas MERCADOPAGO_ACCESS_TOKEN não está definido.',
            );
          }
          return new MercadoPagoPspGateway(token);
        }
        return new SandboxPspGateway();
      },
    },
  ],
})
export class PagamentosModule {}
