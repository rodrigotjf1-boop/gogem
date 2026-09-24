import {
  ConflictException,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  RegemErroNfce,
  RegemNfce,
  RegemRecusouError,
  RegemSalesClient,
  type RegemVendaExternaResposta,
} from '../integracoes/regem/regem-sales.client';
import {
  CancelamentoService,
  type EstornoResultado,
} from '../pagamentos/cancelamento.service';
import { VendaTotemDto, VendaFalhaTotemDto } from './dto/venda-totem.dto';

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
  /**
   * Resultado fiscal (contrato do Regem #574): `null` = não se espera nota; `autorizada` ou
   * `contingencia` com o `danfe` para imprimir; `nao_emitida` com o `erro` — a venda foi
   * desfeita no Regem e o pagamento, estornado aqui.
   */
  nfce?: RegemNfce | null;
  idempotente?: boolean;
  /** A venda NÃO vale (nota não emitida, ou cancelada pelo painel/Regem). */
  cancelado?: boolean;
  /** O estorno feito agora (nota não emitida) — o totem mostra ao cliente. */
  estorno?: EstornoResultado;
}

/**
 * O motivo da venda desfeita por falta de nota, no MESMO formato que o Regem grava
 * (`motivoVendaDesfeita`): quem lê os dois relatórios vê o mesmo texto.
 */
export function motivoNotaNaoEmitida(erro?: RegemErroNfce | null): string {
  if (!erro) return 'NFC-e não emitida';
  const cod = erro.codigo ? ` ${erro.codigo}` : '';
  return `NFC-e não emitida (${erro.etapa}${cod}): ${erro.motivo}`.slice(
    0,
    500,
  );
}

/**
 * Traduz a falha do repasse ao Regem para o totem, preservando a CLASSE do erro:
 *  - recusa definitiva do Regem → 422 (reenviar dá o mesmo: o totem tira da fila e estorna);
 *  - rede, tempo esgotado, 5xx, integração sem configuração → 503 (o totem reenvia depois).
 * Antes tudo virava 500 genérico, e o totem insistia para sempre numa venda recusada — e
 * parava a fila inteira atrás dela.
 */
function erroParaTotem(err: unknown): Error {
  if (err instanceof RegemRecusouError) {
    return new UnprocessableEntityException({
      message: `O sistema da loja recusou a venda: ${err.motivo}`,
      motivo: err.motivo,
    });
  }
  const m = err instanceof Error ? err.message : String(err);
  return new ServiceUnavailableException(
    `Sistema da loja indisponível agora — a venda será reenviada: ${m}`.slice(
      0,
      500,
    ),
  );
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
    private readonly cancelamento: CancelamentoService,
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

    // Já concluído: devolve a MESMA resposta da primeira vez — com a nota. O totem reenvia
    // justamente quando a primeira resposta se perdeu; devolver só comanda e senha fazia o
    // cliente sair sem o DANFE de uma nota emitida (ERR-019).
    // CANCELADO não reabre nunca: reenviar ao Regem traria de volta ao faturamento uma venda
    // desfeita (nota não emitida) ou cancelada pelo painel.
    if (
      existente &&
      (existente.status === 'enviado' || existente.status === 'cancelado')
    ) {
      return respostaGuardada(existente);
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

    // 2.5 DINHEIRO: NÃO é venda fechada. Vira RETIRADA "a receber" no Regem
    //     (/delivery/totem-dinheiro), cobrada no balcão. Relay best-effort — o
    //     cliente já tem o cupom "EFETUAR PAGAMENTO NO CAIXA".
    const ehDinheiro =
      pagamentosReais.length > 0 &&
      pagamentosReais.every(
        (p) => (p.forma ?? '').toLowerCase() === 'dinheiro',
      );
    if (ehDinheiro) {
      return this.relayDinheiro(pedido.id, dto, totalCentavos);
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
      throw erroParaTotem(err);
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

    // 5. A NOTA NÃO SAIU (Regem #574): no totem, sem cupom fiscal não há compra — o Regem já
    //    desfez a venda. O pagamento é estornado AQUI, na hora, sem depender de o totem voltar
    //    a falar com a nuvem, e o pedido fica cancelado com o motivo fiscal (é o que o
    //    relatório mostra). Idempotente: o totem pedir o estorno de novo não estorna em dobro.
    if (resposta.nfce?.status === 'nao_emitida') {
      const motivo = motivoNotaNaoEmitida(resposta.nfce.erro);
      const r = await this.cancelamento.estornarPorOrder(
        dto.idempotencyKey,
        motivo,
        'regem-fiscal',
        { etapa: resposta.nfce.erro?.etapa },
      );
      this.logger.warn(
        `Venda ${dto.idempotencyKey} sem NFC-e — desfeita no Regem, estorno ${r.estorno.feito ? 'solicitado' : 'NÃO saiu'}: ${motivo}`,
      );
      return {
        comandaId: resposta.comandaId,
        senha: resposta.senha,
        total: resposta.total,
        nfce: resposta.nfce,
        cancelado: true,
        estorno: r.estorno,
      };
    }

    return {
      comandaId: resposta.comandaId,
      senha: resposta.senha,
      total: resposta.total,
      nfce: resposta.nfce ?? null,
    };
  }

  /**
   * Relay do pedido em DINHEIRO → RETIRADA "a receber" no Regem
   * (`/delivery/totem-dinheiro`), cobrada no balcão. Em falha grava `falha` + motivo e
   * DEVOLVE O ERRO ao totem (503 passageiro / 422 recusa): o totem imprime o cupom com a
   * senha local do mesmo jeito e a fila dele reenvia. Antes respondia 201 com a senha local
   * e ninguém reenviava — o pedido nunca chegava ao balcão (ERR-015).
   */
  private async relayDinheiro(
    pedidoId: string,
    dto: VendaTotemDto,
    totalCentavos: number,
  ): Promise<VendaTotemResultado> {
    try {
      const resp = await this.regem.lancarTotemDinheiro({
        idempotencyKey: dto.idempotencyKey,
        itens: dto.itens,
        cliente: dto.cliente ?? undefined,
        senhaPlataforma:
          dto.senhaLocal != null ? String(dto.senhaLocal) : undefined,
        totalCentavos,
      });
      await this.prisma.pedido.update({
        where: { id: pedidoId },
        data: {
          status: 'enviado',
          erro: null,
          regemComandaId: resp.comandaId ?? null,
          regemSenha: resp.senha ?? null,
          regemResposta: resp as unknown as Prisma.InputJsonValue,
        },
      });
      return {
        comandaId: resp.comandaId ?? '',
        senha: resp.senha ?? dto.senhaLocal ?? null,
        total: resp.total,
      };
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      await this.prisma.pedido.update({
        where: { id: pedidoId },
        data: { status: 'falha', erro: motivo },
      });
      this.logger.warn(
        `Dinheiro ${dto.idempotencyKey} — relay /delivery/totem-dinheiro falhou: ${motivo}`,
      );
      throw erroParaTotem(err);
    }
  }

  /**
   * Reporta um pagamento que NÃO passou (erro/recusa/timeout/cancelamento).
   * Grava o `Pedido` local como `falha` + `motivo` (espelho p/ relatórios) e
   * relata ao Regem (cupom "não passou"). NUNCA relança — é best-effort: o
   * cliente já viu o erro na tela do totem. NÃO baixa estoque nem caixa.
   */
  async registrarFalhaTotem(
    ctx: DeviceCtxInfo,
    dto: VendaFalhaTotemDto,
  ): Promise<{ ok: boolean }> {
    const totalCentavos = dto.pagamentos.reduce(
      (s, p) => s + (p.valor || 0),
      0,
    );
    const formaTentada = dto.pagamentos[0]?.forma ?? 'desconhecida';
    const itens = dto.itens as unknown as Prisma.InputJsonValue;
    const pagamentos = dto.pagamentos as unknown as Prisma.InputJsonValue;

    // 1. Espelho local: grava/atualiza o Pedido como 'falha' + motivo. Nunca
    //    sobrescreve um pedido já 'enviado' (uma falha anterior à retentativa
    //    bem-sucedida não deve apagar a venda). Idempotente por idempotencyKey.
    try {
      const existente = await this.prisma.pedido.findFirst({
        where: { idempotencyKey: dto.idempotencyKey },
      });
      if (!existente || existente.status !== 'enviado') {
        const data = {
          status: 'falha',
          erro: dto.motivo,
          cpf: dto.cpf ?? null,
          cliente: dto.cliente ?? null,
          consumo: dto.consumo ?? 'local',
          dispositivoId: ctx.deviceId,
          itens,
          pagamentos,
          totalCentavos,
          senhaLocal: dto.senhaLocal ?? null,
        };
        if (existente) {
          await this.prisma.pedido.update({
            where: { id: existente.id },
            data,
          });
        } else {
          await this.prisma.pedido.create({
            data: {
              idempotencyKey: dto.idempotencyKey,
              ...data,
            } as Prisma.PedidoUncheckedCreateInput,
          });
        }
      }
    } catch (err) {
      this.logger.warn(
        `Falha ao gravar Pedido 'falha' ${dto.idempotencyKey}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }

    // 2. Relata ao Regem (best-effort — cupom "não passou" + motivo).
    await this.regem.relatarFalha({
      idempotencyKey: dto.idempotencyKey,
      itens: dto.itens,
      formaTentada,
      totalCentavos,
      senhaPlataforma:
        dto.senhaLocal != null ? String(dto.senhaLocal) : undefined,
      motivo: dto.motivo,
    });

    return { ok: true };
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
  ): Promise<
    Array<VendaTotemDto['pagamentos'][number] & { bandeira?: string }>
  > {
    const pp = await this.prisma.pointPayment.findFirst({
      where: { orderId: dto.idempotencyKey },
    });
    const real = pp?.status === 'approved' ? pp.tipo : null;
    if (!real || real === 'credit' || real === 'debit') return dto.pagamentos;
    const bandeira = pp?.bandeira ?? undefined;
    return dto.pagamentos.map((p) =>
      ehCartao(p.forma)
        ? { ...p, forma: real, ...(bandeira ? { bandeira } : {}) }
        : p,
    );
  }
}

/**
 * A resposta guardada da primeira vez (idempotência). Pedido cancelado sem resposta do Regem
 * (cancelado pelo painel antes de chegar lá) não tem o que devolver: 409, que a fila do totem
 * já entende como "este pedido está resolvido, pare de reenviar".
 */
function respostaGuardada(p: {
  status: string;
  regemComandaId: string | null;
  regemSenha: number | null;
  regemResposta: Prisma.JsonValue | null;
}): VendaTotemResultado {
  const r = (p.regemResposta ?? null) as RegemVendaExternaResposta | null;
  const cancelado = p.status === 'cancelado';
  if (cancelado && !r) {
    throw new ConflictException('Pedido cancelado — não é reenviado ao Regem.');
  }
  return {
    comandaId: p.regemComandaId ?? r?.comandaId ?? '',
    senha: p.regemSenha ?? r?.senha ?? null,
    total: r?.total ?? null,
    nfce: r?.nfce ?? null,
    idempotente: true,
    ...(cancelado ? { cancelado: true } : {}),
  };
}

/** Rótulos que representam cartão (placeholder do totem) — não PIX/dinheiro. */
function ehCartao(forma: string): boolean {
  const f = (forma ?? '').toLowerCase();
  return f !== 'pix' && f !== 'dinheiro';
}
