import { Injectable } from '@nestjs/common';
import { RegemConfigResolver, type RegemConfig } from './regem-config.resolver';
import { chamarRegem, mensagemDoRegem } from './chamada-regem';

export { mensagemDoRegem };

/**
 * Cliente HTTP de venda do Regem (issue #12.2).
 *
 * Lança a venda de totem no Regem via `POST {apiBase}/vendas/externa-pdv`
 * (endpoint L-VEN-1, PR #226 do Regem). A credencial (token de integração
 * `Bearer rgm_it_…` ou o `X-Sync-Token` de sempre), o prazo e as respostas de
 * erro moram em `chamada-regem.ts`. Base e tokens vêm da integração da
 * loja/empresa (`RegemConfigResolver`) — NUNCA hardcoded (CLAUDE.md §8).
 *
 * O endpoint do Regem é idempotente por `idempotencyKey` (replay devolve
 * `{ comandaId, idempotente: true }`), somando-se à idempotência local do GoGeM
 * (unique `(tenantId, idempotencyKey)` em `Pedido`).
 *
 * ⚠️ CONTRATO DE DADOS DO REGEM (conferido no código do Regem):
 *   - `pagamentos[].valor` vai em **REAIS decimais** (ex.: 29.90), NÃO centavos.
 *     O Regem deriva o total de `precoVenda` (reais) e exige `somaPag ≈ total`
 *     (tolerância 0,05). Enviar centavos faz toda venda paga falhar com 400.
 *   - `senhaPlataforma` é **string** (o DTO do Regem valida `@IsString`).
 *   A conversão de centavos→reais e número→string acontece no VendasService,
 *   na borda de saída — o GoGeM permanece internamente em centavos (§ dinheiro).
 */

// ── Shape do corpo enviado ao Regem (contrato de `/vendas/externa-pdv`) ──────

/** Item da venda, casado no Regem por `codigoPdv` (de-para §4). */
export interface RegemVendaItem {
  codigoPdv: string;
  quantidade: number;
  observacao?: string;
}

/** Forma de pagamento (split). `valor` em REAIS decimais (contrato do Regem). */
export interface RegemVendaPagamento {
  forma: string;
  valor: number;
  nsu?: string;
  autorizacao?: string;
  formaPagamentoId?: string;
}

/** Corpo do lançamento de venda externa no Regem. */
export interface RegemVendaExternaBody {
  idempotencyKey: string;
  itens: RegemVendaItem[];
  pagamentos: RegemVendaPagamento[];
  cpf?: string;
  taxaServicoPct?: number;
  plataforma?: string;
  /** Tipo de consumo: 'local' (comer aqui) | 'viagem'. O Regem roteia/embala. */
  consumo?: 'local' | 'viagem';
  /** Nº do pedido no totem — string (o DTO do Regem valida `@IsString`). */
  senhaPlataforma?: string;
}

/**
 * Resposta do Regem. No caminho feliz traz `comandaId`, `senha`, `subtotal` e
 * `total` (e `nfce?` se fiscal ativo). Em replay idempotente, o Regem devolve
 * `{ comandaId, idempotente: true }` — os demais campos podem faltar.
 */
/**
 * Resumo da NFC-e que o Regem devolve quando a loja emite cupom fiscal (F1/F2).
 *
 * É o que o TOTEM precisa para imprimir o DANFE: o QR já montado (com o CSC), o
 * protocolo de autorização, número E série, e a data. `simulada` e `contingencia` não
 * são enfeite — a primeira avisa que aquilo NÃO é documento fiscal, e a segunda exige a
 * mensagem "EMITIDA EM CONTINGÊNCIA" no papel, conforme o manual do DANFE NFC-e.
 *
 * `unknown` aqui fazia o dado chegar e morrer: o GoGeM recebia a nota e não repassava.
 */
export interface RegemNfce {
  status: string;
  chave?: string | null;
  numero?: number | null;
  serie?: number | null;
  protocolo?: string | null;
  /** URL completa do QR Code fiscal — o totem só renderiza. */
  qrcode?: string | null;
  /** '1' produção · '2' homologação. */
  ambiente?: string;
  simulada?: boolean;
  contingencia?: boolean;
  emitidaEm?: string | null;
  /**
   * K6 — o DANFE já montado pelo EMITENTE, pronto para a impressora térmica do totem
   * (marcador `@QR:` na linha do QR Code). Vem montado de lá porque o totem não tem —
   * nem deve ter — os dados do emitente, os tributos nem a URL de consulta. Repassado
   * sem reescrever: reescrever o documento aqui seria uma segunda versão do DANFE.
   */
  danfe?: string | null;
  /** Contingência com a 2ª via ("VIA DO ESTABELECIMENTO") ligada na loja (mig 287 do Regem). */
  viaEstabelecimento?: boolean;
  /**
   * Só em `status: 'nao_emitida'` (Regem #574): a nota NÃO saiu e a venda foi desfeita lá.
   * `motivo` é o texto do Regem (vai para o relatório); `repete` diz se a próxima venda vai
   * falhar igual (configuração, certificado, emitente) — o totem alerta em vez de estornar em série.
   */
  erro?: RegemErroNfce | null;
}

/** Por que a NFC-e não saiu (contrato do Regem em `fiscal/nfce-totem.ts`). */
export interface RegemErroNfce {
  etapa:
    'configuracao' | 'rejeitada' | 'denegada' | 'sem_contingencia' | 'interno';
  codigo: string | null;
  motivo: string;
  repete: boolean;
}

/**
 * O Regem RECUSOU a venda de forma definitiva (400/422: código PDV que não existe, soma dos
 * pagamentos que não fecha, venda sem itens…). Reenviar a mesma venda dá o mesmo resultado —
 * quem chama deve tirá-la da fila, não insistir.
 */
export class RegemRecusouError extends Error {
  constructor(
    readonly status: number,
    /** A mensagem do Regem, limpa (sem URL nem corpo JSON). */
    readonly motivo: string,
    mensagem: string,
  ) {
    super(mensagem);
    this.name = 'RegemRecusouError';
  }
}

/** Status do Regem que significam recusa DEFINITIVA da venda (o resto é passageiro). */
const STATUS_RECUSA_DEFINITIVA = new Set([400, 422]);

export interface RegemVendaExternaResposta {
  comandaId: string;
  senha?: number;
  subtotal?: number;
  total?: number;
  nfce?: RegemNfce | null;
  idempotente?: boolean;
}

/**
 * Corpo do reporte de FALHA/cancelamento de pagamento ao Regem
 * (`POST /vendas/externa-pdv/falha`). NÃO é uma venda: o Regem lista o cupom
 * "não passou" + `motivo`, sem caixa e sem estoque. `totalCentavos` em CENTAVOS
 * (é só exibição — diferente da venda, que vai em reais).
 */
export interface RegemVendaFalhaBody {
  idempotencyKey: string;
  itens: RegemVendaItem[];
  formaTentada: string;
  totalCentavos: number;
  senhaPlataforma?: string;
  motivo: string;
}

/**
 * Corpo do pedido em DINHEIRO ao Regem (`POST /delivery/totem-dinheiro`).
 * NÃO é venda fechada: vira uma RETIRADA "Totem GoGeM" a receber, cobrada no
 * balcão (finalização no Regem). Idempotente por `idempotencyKey`. `totalCentavos`
 * é opcional (o Regem recalcula pelo preço do servidor).
 */
export interface RegemTotemDinheiroBody {
  idempotencyKey: string;
  itens: RegemVendaItem[];
  cliente?: string;
  senhaPlataforma?: string;
  totalCentavos?: number;
}

/** Timeout padrão da requisição ao Regem (ms). */
const FETCH_TIMEOUT_MS = 15_000;

/**
 * Prazo da VENDA paga (ms). Com NFC-e o Regem só responde depois da nota: até ~12 s na
 * primeira vez (10 s de SEFAZ + contingência) e até 25 s quando a repetição espera uma
 * emissão em andamento. O totem espera 45 s; 30 s aqui deixam folga para a volta.
 */
const VENDA_TIMEOUT_MS = 30_000;

@Injectable()
export class RegemSalesClient {
  constructor(private readonly resolver: RegemConfigResolver) {}

  /**
   * Lança a venda de totem no Regem (config resolvida por tenant). Lança erro
   * claro quando a config está ausente ou a resposta não é 2xx (status + corpo).
   */
  async lancarVendaExterna(
    body: RegemVendaExternaBody,
  ): Promise<RegemVendaExternaResposta> {
    const cfg = await this.resolver.resolve();
    const res = await chamarRegem(this.resolver, cfg, {
      caminho: '/vendas/externa-pdv',
      metodo: 'POST',
      corpo: body,
      prazoMs: VENDA_TIMEOUT_MS,
      rotulo: 'a venda',
    });

    if (!res.ok) {
      // Inclui o corpo do erro para diagnóstico (best-effort).
      const corpo = await res.text().catch(() => '');
      const mensagem = `Venda no Regem respondeu ${res.status} ${res.statusText} (${cfg.base}/vendas/externa-pdv): ${corpo}`;
      if (STATUS_RECUSA_DEFINITIVA.has(res.status)) {
        throw new RegemRecusouError(
          res.status,
          mensagemDoRegem(corpo),
          mensagem,
        );
      }
      throw new Error(mensagem);
    }

    return (await res.json()) as RegemVendaExternaResposta;
  }

  /**
   * Lança um pedido em DINHEIRO no Regem como RETIRADA a receber
   * (`POST /delivery/totem-dinheiro`). Credencial como nas outras rotas
   * (`chamada-regem.ts`). Idempotente por `idempotencyKey`. Lança erro em falha —
   * o VendasService decide o tratamento (best-effort para o totem).
   */
  async lancarTotemDinheiro(
    body: RegemTotemDinheiroBody,
  ): Promise<RegemVendaExternaResposta> {
    const cfg = await this.resolver.resolve();
    const res = await chamarRegem(this.resolver, cfg, {
      caminho: '/delivery/totem-dinheiro',
      metodo: 'POST',
      corpo: body,
      prazoMs: FETCH_TIMEOUT_MS,
      rotulo: 'o pedido em dinheiro',
    });
    if (!res.ok) {
      const corpo = await res.text().catch(() => '');
      const mensagem = `Pedido dinheiro no Regem respondeu ${res.status} ${res.statusText} (${cfg.base}/delivery/totem-dinheiro): ${corpo}`;
      if (STATUS_RECUSA_DEFINITIVA.has(res.status)) {
        throw new RegemRecusouError(
          res.status,
          mensagemDoRegem(corpo),
          mensagem,
        );
      }
      throw new Error(mensagem);
    }
    // Resposta pode vir vazia/variada — parse defensivo. A SENHA da retirada (a
    // que a cozinha/balcão chama) pode vir como `senha`, `numero` ou
    // `senhaPlataforma`: normaliza para `senha`, pois o totem mostra ESSA senha
    // (senão o cliente sai com a senha local e o balcão chama outra).
    const b = (await res.json().catch(() => ({}))) as {
      comandaId?: string;
      senha?: number | string;
      numero?: number | string;
      senhaPlataforma?: number | string;
      total?: number;
    };
    const senhaRaw = b.senha ?? b.numero ?? b.senhaPlataforma;
    const senha = senhaRaw == null ? undefined : Number(senhaRaw);
    return {
      comandaId: b.comandaId,
      senha: senha != null && Number.isFinite(senha) ? senha : undefined,
      total: b.total,
    } as RegemVendaExternaResposta;
  }

  /**
   * Reporta ao Regem um pagamento que NÃO passou (cupom "não passou" + motivo).
   * BEST-EFFORT: nunca lança — sem config Regem, 404 (endpoint ainda não criado
   * no Regem) ou erro de rede são silenciosos. Nada de venda/caixa é registrado.
   */
  async relatarFalha(body: RegemVendaFalhaBody): Promise<void> {
    let cfg: RegemConfig;
    try {
      cfg = await this.resolver.resolve();
    } catch {
      return; // sem integração Regem → nada a reportar
    }
    try {
      await chamarRegem(this.resolver, cfg, {
        caminho: '/vendas/externa-pdv/falha',
        metodo: 'POST',
        corpo: body,
        prazoMs: FETCH_TIMEOUT_MS,
        rotulo: 'a falha do pagamento',
      });
      // best-effort: não checamos res.ok nem lançamos.
    } catch {
      // rede/timeout/recusa — silencioso (o cliente já viu o erro na tela do
      // totem; a recusa do token novo já ficou marcada no painel).
    }
  }
}
