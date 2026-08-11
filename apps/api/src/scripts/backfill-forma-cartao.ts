/* eslint-disable no-console */
import { Prisma, PrismaClient } from '@prisma/client';
import { classificarPagamento } from '../pagamentos/psp/mercadopago-point.gateway';

/**
 * Backfill da forma REAL do cartão em pedidos ANTIGOS (antes do enriquecimento
 * automático). Pedidos já enviados guardaram `forma='credito'` (placeholder) e o
 * PointPayment ficou com `tipo='credit'` — a verdade só existe no Mercado Pago.
 *
 * Para cada PointPayment aprovado com `paymentId`, re-consulta o MP
 * (`GET /v1/payments/:id`) usando o token da loja (Integracao mercadopago),
 * normaliza tipo+bandeira, grava no PointPayment e reescreve o `Pedido` casado
 * (`idempotencyKey = orderId`): troca a forma do pagamento de cartão e anexa a
 * bandeira. PIX/dinheiro não mudam. Idempotente — seguro re-rodar.
 *
 * Uso (dentro do container da API, onde DATABASE_URL existe):
 *   node dist/scripts/backfill-forma-cartao.js            # aplica
 *   node dist/scripts/backfill-forma-cartao.js --dry      # só relata, não grava
 * (ou em dev: npm run backfill:forma-cartao [-- --dry])
 */

const MP = 'https://api.mercadopago.com';
const DRY = process.argv.includes('--dry') || process.env.DRY === '1';

/** Rótulos que representam cartão (placeholder do totem) — não PIX/dinheiro. */
function ehCartao(forma: unknown): boolean {
  const f = (typeof forma === 'string' ? forma : '').toLowerCase();
  return !!f && f !== 'pix' && f !== 'dinheiro';
}

async function tokenDoTenant(
  prisma: PrismaClient,
  cache: Map<string, string | null>,
  tenantId: string,
): Promise<string | null> {
  if (cache.has(tenantId)) return cache.get(tenantId) ?? null;
  const integ = await prisma.integracao.findFirst({
    where: { tenantId, tipo: 'mercadopago', ativo: true },
  });
  const cfg = integ?.config as Record<string, string> | null;
  const token = cfg?.accessToken ?? null;
  cache.set(tenantId, token);
  return token;
}

async function main(): Promise<void> {
  const prisma = new PrismaClient();
  const cacheToken = new Map<string, string | null>();
  let atualizadosPP = 0;
  let atualizadosPedido = 0;
  let semToken = 0;
  let semDetalhe = 0;
  let semMudanca = 0;

  console.log(
    `[backfill] início ${DRY ? '(DRY-RUN — não grava)' : '(aplicando)'}`,
  );

  // Só pagamentos aprovados com id do MP (o não-aprovado não tem forma real).
  const pagamentos = await prisma.pointPayment.findMany({
    where: { status: 'approved', NOT: { paymentId: null } },
    orderBy: { createdAt: 'asc' },
  });
  console.log(`[backfill] ${pagamentos.length} PointPayment(s) aprovados`);

  for (const pp of pagamentos) {
    const token = await tokenDoTenant(prisma, cacheToken, pp.tenantId);
    if (!token) {
      semToken++;
      continue;
    }
    // Detalhe do MP → forma real + bandeira.
    let tipo: string;
    let bandeira: string | null;
    try {
      const res = await fetch(`${MP}/v1/payments/${pp.paymentId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        semDetalhe++;
        continue;
      }
      const b = (await res.json()) as {
        payment_type_id?: string;
        payment_method_id?: string;
      };
      ({ tipo, bandeira } = classificarPagamento(
        b.payment_type_id,
        b.payment_method_id,
      ));
    } catch {
      semDetalhe++;
      continue;
    }

    const mudouPP = pp.tipo !== tipo || (pp.bandeira ?? null) !== bandeira;
    if (mudouPP && !DRY) {
      await prisma.pointPayment.update({
        where: { id: pp.id },
        data: { tipo, bandeira },
      });
    }
    if (mudouPP) atualizadosPP++;

    // Reescreve o Pedido casado (mesma loja, idempotencyKey = orderId).
    const pedido = await prisma.pedido.findFirst({
      where: { tenantId: pp.tenantId, idempotencyKey: pp.orderId },
    });
    if (!pedido || !Array.isArray(pedido.pagamentos)) {
      if (!mudouPP) semMudanca++;
      continue;
    }
    let mudouPedido = false;
    const pagamentosCorrigidos = (pedido.pagamentos as unknown[]).map((raw) => {
      if (!raw || typeof raw !== 'object') return raw;
      const p = raw as Record<string, unknown>;
      if (!ehCartao(p.forma)) return raw;
      const novo: Record<string, unknown> = { ...p, forma: tipo };
      if (bandeira) novo.bandeira = bandeira;
      if (p.forma !== tipo || (p.bandeira ?? null) !== (bandeira ?? null)) {
        mudouPedido = true;
      }
      return novo;
    });
    if (mudouPedido && !DRY) {
      await prisma.pedido.update({
        where: { id: pedido.id },
        data: {
          pagamentos: pagamentosCorrigidos as unknown as Prisma.InputJsonValue,
        },
      });
    }
    if (mudouPedido) {
      atualizadosPedido++;
      console.log(
        `[backfill] pedido ${pedido.idempotencyKey.slice(0, 8)}… → ${tipo}${
          bandeira ? ` · ${bandeira}` : ''
        }`,
      );
    } else if (!mudouPP) {
      semMudanca++;
    }
  }

  console.log(
    `[backfill] fim — PointPayment atualizados: ${atualizadosPP}, ` +
      `Pedidos atualizados: ${atualizadosPedido}, sem token: ${semToken}, ` +
      `sem detalhe no MP: ${semDetalhe}, sem mudança: ${semMudanca}` +
      `${DRY ? ' (DRY-RUN — nada foi gravado)' : ''}`,
  );
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error('[backfill] erro fatal:', e);
  process.exit(1);
});
