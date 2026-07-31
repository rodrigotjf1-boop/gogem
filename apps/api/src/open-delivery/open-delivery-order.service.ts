import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOpenDeliveryOrderDto } from './dto/create-order.dto';

/**
 * Pedidos + eventos do Open Delivery (GoGeM provedor). Ingest idempotente por
 * (tenant, displayId); máquina de status; fila de eventos consumida por
 * long-polling + acknowledgment. Dinheiro chega em REAIS (guardamos o payload OD
 * + total em centavos). A materialização em comanda/produção é follow-up.
 */
@Injectable()
export class OpenDeliveryOrderService {
  constructor(private readonly prisma: PrismaService) {}

  /** Recebe um pedido do parceiro. Reenvio (mesmo displayId) devolve o existente. */
  async ingest(dto: CreateOpenDeliveryOrderDto, appId?: string) {
    const existente = await this.prisma.openDeliveryOrder.findFirst({
      where: { displayId: dto.displayId },
    });
    if (existente) return this.toOD(existente);

    const totalCentavos = Math.round((dto.total?.value ?? 0) * 100);
    const data = {
      appId: appId ?? null,
      displayId: dto.displayId,
      status: 'PLACED',
      customerNome: dto.customer?.name ?? null,
      customerDoc: dto.customer?.document ?? null,
      itens: dto.items as unknown as Prisma.InputJsonValue,
      pagamentos: dto.payments as unknown as Prisma.InputJsonValue,
      totalCentavos,
    } satisfies Omit<Prisma.OpenDeliveryOrderUncheckedCreateInput, 'tenantId'>;

    const order = await this.prisma.openDeliveryOrder.create({
      data: data as Prisma.OpenDeliveryOrderUncheckedCreateInput,
    });
    await this.emitir('ORDER_PLACED', order.id);
    return this.toOD(order);
  }

  /** Busca um pedido por id (404 se não for do tenant). */
  async obter(id: string) {
    const order = await this.prisma.openDeliveryOrder.findFirst({
      where: { id },
    });
    if (!order) throw new NotFoundException('Pedido não encontrado.');
    return this.toOD(order);
  }

  /** Atualiza o status e emite o evento correspondente. */
  async atualizarStatus(id: string, status: string) {
    const order = await this.prisma.openDeliveryOrder.findFirst({
      where: { id },
    });
    if (!order) throw new NotFoundException('Pedido não encontrado.');
    if (order.status === 'CONCLUDED' || order.status === 'CANCELLED') {
      throw new BadRequestException(
        `Pedido ${order.status.toLowerCase()} não muda de status.`,
      );
    }
    const atualizado = await this.prisma.openDeliveryOrder.update({
      where: { id },
      data: { status },
    });
    await this.emitir(
      status === 'CANCELLED' ? 'ORDER_CANCELLED' : 'ORDER_STATUS_CHANGED',
      id,
    );
    return this.toOD(atualizado);
  }

  /** Long-polling: eventos pendentes (não confirmados), mais antigos primeiro. */
  async eventos(limite = 50) {
    const eventos = await this.prisma.openDeliveryEvent.findMany({
      where: { acknowledgedAt: null },
      orderBy: { createdAt: 'asc' },
      take: Math.min(Math.max(limite, 1), 200),
    });
    return eventos.map((e) => ({
      id: e.id,
      type: e.tipo,
      orderId: e.orderId,
      createdAt: e.createdAt.toISOString(),
    }));
  }

  /** Confirma (remove da fila) os eventos pelos ids. */
  async ack(ids: string[]): Promise<{ acknowledged: number }> {
    if (!ids.length) return { acknowledged: 0 };
    const r = await this.prisma.openDeliveryEvent.updateMany({
      where: { id: { in: ids }, acknowledgedAt: null },
      data: { acknowledgedAt: new Date() },
    });
    return { acknowledged: r.count };
  }

  // ── internos ──────────────────────────────────────────────────────────────

  private async emitir(tipo: string, orderId: string): Promise<void> {
    const data = {
      tipo,
      orderId,
    } satisfies Omit<Prisma.OpenDeliveryEventUncheckedCreateInput, 'tenantId'>;
    await this.prisma.openDeliveryEvent.create({
      data: data as Prisma.OpenDeliveryEventUncheckedCreateInput,
    });
  }

  /** Registro interno → formato Open Delivery (reais). */
  private toOD(o: {
    id: string;
    tenantId: string;
    displayId: string;
    status: string;
    customerNome: string | null;
    customerDoc: string | null;
    itens: Prisma.JsonValue;
    pagamentos: Prisma.JsonValue;
    totalCentavos: number;
    createdAt: Date;
  }) {
    return {
      id: o.id,
      displayId: o.displayId,
      merchantId: o.tenantId,
      status: o.status,
      createdAt: o.createdAt.toISOString(),
      customer:
        o.customerNome || o.customerDoc
          ? {
              name: o.customerNome ?? undefined,
              document: o.customerDoc ?? undefined,
            }
          : undefined,
      items: o.itens,
      payments: o.pagamentos,
      total: { value: o.totalCentavos / 100, currency: 'BRL' },
    };
  }
}
