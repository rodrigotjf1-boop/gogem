import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  RegemSalesClient,
  type RegemVendaExternaResposta,
} from '../integracoes/regem/regem-sales.client';
import { VendaTotemDto } from './dto/venda-totem.dto';

/** Plataforma reportada ao Regem (origem da venda). */
const PLATAFORMA = 'GoGeM Totem';

/**
 * Converte centavos inteiros → reais decimais com 2 casas (formato do fio do
 * Regem, que compara `somaPag` com o total em reais). Ex.: 2990 → 29.9.
 */
function centavosParaReais(centavos: number): number {
  return Math.round(centavos) / 100;
}

/**
 * Contexto do dispositivo autenticado (do DeviceTokenGuard, via `@DeviceCtx()`).
 * Só usamos `deviceId` aqui; `tenantId` é aplicado pelo middleware do Prisma.
 */
export interface DeviceCtxInfo {
  tenantId: string;
  deviceId: string;
  unidadeId: string | null;
}

/** Resultado devolvido ao totem. */
export interface VendaTotemResultado {
  comandaId: string;
  senha?: number | null;
  total?: number | null;
  nfce?: unknown;
  idempotente?: boolean;
}

/**
 * VendasService — repasse da venda de totem ao Regem (issue #12.2).
 *
 * O totem fala SÓ com o GoGeM. Este serviço grava o `Pedido` (tenant-scoped) e
 * lança a venda no Regem (`RegemSalesClient`), guardando o `REGEM_SYNC_TOKEN`
 * no servidor — o token do Regem não se espalha por totem.
 *
 * Idempotência dupla (CLAUDE.md §1):
 *   - LOCAL: `Pedido` tem unique `(tenantId, idempotencyKey)`. Se já existe e
 *     está `enviado`, devolvemos o resultado guardado SEM repostar no Regem.
 *   - REMOTA: o próprio endpoint do Regem dedupe pela mesma `idempotencyKey`.
 *
 * Multi-tenant (§2): NUNCA passamos `tenantId` à mão — o `tenantScopeMiddleware`
 * injeta o tenant do contexto (aberto pelo TenantContextInterceptor a partir do
 * `req.user.tenantId` que o DeviceTokenGuard setou).
 */
@Injectable()
export class VendasService {
  private readonly logger = new Logger(VendasService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly regem: RegemSalesClient,
  ) {}

  async registrarVendaTotem(
    ctx: DeviceCtxInfo,
    dto: VendaTotemDto,
  ): Promise<VendaTotemResultado> {
    // 1. Idempotência local: o middleware escopa por tenant (não adicionamos
    //    tenantId à mão). Se já foi enviado, devolvemos o guardado.
    const existente = await this.prisma.pedido.findFirst({
      where: { idempotencyKey: dto.idempotencyKey },
    });

    if (existente && existente.status === 'enviado') {
      return {
        comandaId: existente.regemComandaId as string,
        senha: existente.regemSenha,
        idempotente: true,
      };
    }

    // 2. Cria (ou reabre um pedido que falhou) em status `pendente`. O
    //    `tenantId` NÃO entra no data — o middleware injeta (§2); o cast segue
    //    o padrão do DispositivoService (satisfies Omit<...,'tenantId'>).
    // Forma REAL do cartão: o cliente escolhe crédito/débito/voucher NA
    // maquininha, então o totem manda 'credito' como placeholder. Corrige pela
    // forma real (do PointPayment) — vale pro relatório do GoGeM E pro Regem.
    const pagamentosReais = await this.corrigirFormaCartao(dto);
    const itens = dto.itens as unknown as Prisma.InputJsonValue;
    const pagamentos = pagamentosReais as unknown as Prisma.InputJsonValue;
    // Total do pedido (centavos) = soma dos pagamentos — base do faturamento.
    const totalCentavos = pagamentosReais.reduce(
      (s, p) => s + (p.valor || 0),
      0,
    );

    let pedido: { id: string };
    if (existente) {
      pedido = await this.prisma.pedido.update({
        where: { id: existente.id },
        data: {
          status: 'pendente',
          erro: null,
          cpf: dto.cpf ?? null,
          cliente: dto.cliente ?? null,
          consumo: dto.consumo ?? 'local',
          dispositivoId: ctx.deviceId,
          itens,
          pagamentos,
          totalCentavos,
          taxaServicoPct: dto.taxaServicoPct ?? null,
          senhaLocal: dto.senhaLocal ?? null,
        },
      });
    } else {
      const data = {
        idempotencyKey: dto.idempotencyKey,
        status: 'pendente',
        cpf: dto.cpf ?? null,
        cliente: dto.cliente ?? null,
        consumo: dto.consumo ?? 'local',
        dispositivoId: ctx.deviceId,
        itens,
        pagamentos,
        totalCentavos,
        taxaServicoPct: dto.taxaServicoPct ?? null,
        senhaLocal: dto.senhaLocal ?? null,
      } satisfies Omit<Prisma.PedidoUncheckedCreateInput, 'tenantId'>;
      pedido = await this.prisma.pedido.create({
        data: data as Prisma.PedidoUncheckedCreateInput,
      });
    }

    // 3. Repassa ao Regem. Falha → grava `falha` + erro e RELANÇA (o totem
    //    re-tenta depois com a MESMA idempotencyKey; o Regem também dedupe).
    let resposta: RegemVendaExternaResposta;
    try {
      resposta = await this.regem.lancarVendaExterna({
        idempotencyKey: dto.idempotencyKey,
        itens: dto.itens,
        // Borda de saída: o Regem espera REAIS decimais e senha em string
        // (o GoGeM guarda tudo em centavos/inteiro internamente).
        pagamentos: pagamentosReais.map((p) => ({
          forma: p.forma,
          valor: centavosParaReais(p.valor),
          nsu: p.nsu,
          autorizacao: p.autorizacao,
          formaPagamentoId: p.formaPagamentoId,
        })),
        cpf: dto.cpf,
        taxaServicoPct: dto.taxaServicoPct,
        plataforma: PLATAFORMA,
        consumo: dto.consumo ?? 'local',
        senhaPlataforma:
          dto.senhaLocal != null ? String(dto.senhaLocal) : undefined,
      });
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      await this.prisma.pedido.update({
        where: { id: pedido.id },
        data: { status: 'falha', erro: motivo },
      });
      this.logger.warn(
        `Venda ${dto.idempotencyKey} falhou no Regem: ${motivo}`,
      );
      throw err;
    }

    // 4. Sucesso: guarda o resultado do Regem.
    await this.prisma.pedido.update({
      where: { id: pedido.id },
      data: {
        status: 'enviado',
        erro: null,
        regemComandaId: resposta.comandaId,
        regemSenha: resposta.senha ?? null,
        regemResposta: resposta as unknown as Prisma.InputJsonValue,
      },
    });

    return {
      comandaId: resposta.comandaId,
      senha: resposta.senha,
      total: resposta.total,
      nfce: resposta.nfce,
    };
  }

  /**
   * Troca o rótulo do pagamento de cartão pela forma REAL do MP Point. O totem
   * manda 'credito' como placeholder (o cliente só escolhe crédito/débito/
   * voucher NA maquininha). Se há um PointPayment aprovado deste pedido
   * (orderId = idempotencyKey), usa o `tipo` já enriquecido pelo backend
   * (credito|debito|voucher|…). PIX/dinheiro não mudam. Se não houver
   * PointPayment ou o `tipo` ainda for o placeholder inglês ('credit'/'debit',
   * = o enriquecimento no MP não rodou), mantém o que veio do totem.
   */
  private async corrigirFormaCartao(
    dto: VendaTotemDto,
  ): Promise<VendaTotemDto['pagamentos']> {
    const pp = await this.prisma.pointPayment.findFirst({
      where: { orderId: dto.idempotencyKey },
    });
    const real = pp?.status === 'approved' ? pp.tipo : null;
    if (!real || real === 'credit' || real === 'debit') return dto.pagamentos;
    return dto.pagamentos.map((p) =>
      ehCartao(p.forma) ? { ...p, forma: real } : p,
    );
  }
}

/** Rótulos que representam cartão (placeholder do totem) — não PIX/dinheiro. */
function ehCartao(forma: string): boolean {
  const f = (forma ?? '').toLowerCase();
  return f !== 'pix' && f !== 'dinheiro';
}
