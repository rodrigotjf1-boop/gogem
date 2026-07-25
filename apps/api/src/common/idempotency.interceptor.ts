import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';

/**
 * Cabeçalho HTTP padrão de idempotência.
 */
export const IDEMPOTENCY_HEADER = 'idempotency-key';

/**
 * IdempotencyInterceptor — STUB documentado (CLAUDE.md §1).
 *
 * Regra de ouro: "todo pedido/pagamento nasce com UUID gerado no totem;
 * endpoints de escrita aceitam `Idempotency-Key` e reenvio jamais duplica
 * venda".
 *
 * Contrato pretendido (a implementar no S1–S2, provavelmente sobre Redis):
 *   1. Só age em métodos de escrita (POST/PUT/PATCH/DELETE).
 *   2. Lê o header `Idempotency-Key`. Ausente em rota de escrita crítica =>
 *      400 (ou 422), conforme política por rota.
 *   3. Chave = hash(tenantId + rota + Idempotency-Key). Primeira vez: executa
 *      o handler, persiste (status + corpo da resposta) com TTL e um lock para
 *      evitar corrida. Reenvio: devolve a resposta guardada SEM reexecutar o
 *      efeito colateral (nunca duplica a venda).
 *   4. Idempotência escopada por tenant — jamais colidir entre tenants.
 *
 * Por ora, apenas repassa a chamada (no-op) para manter o app compilando e
 * runnable. Registrar como interceptor global no bootstrap quando implementado.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  intercept(
    _context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    // TODO(S1–S2): ler IDEMPOTENCY_HEADER, checar/gravar no store (Redis),
    // curto-circuitar reenvios devolvendo a resposta persistida.
    return next.handle();
  }
}
