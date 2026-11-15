import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { cifrar, decifrar } from '../../common/cifra';
import {
  chaveDosSegredos,
  contextoDoSegredo,
  type DonoDoSegredo,
} from '../../integracao/segredos';
import { PrismaService } from '../../prisma/prisma.service';
import {
  lerClique,
  resumoDoClique,
  selarLigacao,
  type CliqueGuardado,
} from './clique-guardado';
import { clienteDmsIdDoGogem } from './dms-id.cliente';
import {
  conferirVolta,
  corpoDoPedido,
  formatoDoNumero,
  gerarPedido,
  hashDoEstado,
  lerConfigDoClique,
  lojaEmUso,
  lojasDaTroca,
  urlDaPagina,
  VALIDADE_DO_PEDIDO_MS,
  type ConfigDoClique,
  type LojaLigada,
} from './regem-clique.regras';
import { RegemAvisosService } from './regem-avisos.service';
import { RegemConfigResolver } from './regem-config.resolver';

type Ligado = Extract<ConfigDoClique, { ligado: true }>;

export interface QuemConecta {
  userId: string;
  tenantId: string;
  email: string;
}

export interface SituacaoDoClique {
  /** O botão aparece: o "Conectar pelo Regem" está configurado neste servidor. */
  disponivel: boolean;
  conectado: boolean;
  emUso: { id: string; nome: string } | null;
  lojas: { id: string; nome: string }[];
  conectadoEm: string | null;
}

const COMECE_DE_NOVO = 'Comece de novo pelo botão "Conectar pelo Regem".';
/** O verificador do PKCE é cifrado com este campo no contexto (a empresa vem do pedido). */
const CAMPO_DO_VERIFICADOR = 'clique:verificador';

/** O botão aparece? A configuração certa, o cliente do DMS ID e a chave dos segredos. */
export function cliqueDisponivel(): boolean {
  return (
    lerConfigDoClique(process.env).ligado &&
    clienteDmsIdDoGogem() !== null &&
    chaveDosSegredos() !== null
  );
}

/** A situação do clique para o painel (nunca a ligação). */
export function situacaoDoClique(clique: unknown): SituacaoDoClique {
  return { disponivel: cliqueDisponivel(), ...resumoDoClique(clique) };
}

/**
 * "CONECTAR PELO REGEM" (Hub DMS, F6, plano "Clique GoGeM → Regem"; migration
 * `20261115000000_regem_clique`). Quem configura a integração não cola token: o GoGeM empurra o
 * pedido ao Regem com o token do DMS ID, o presidente autoriza na página do Regem (loja por loja)
 * e o GoGeM troca o código pela ligação de cada loja marcada, guardada CIFRADA na integração
 * Regem da empresa (coluna `clique`). Nasce DESLIGADO (`GOGEM_REGEM_CLIQUE`): sem a configuração,
 * o botão não aparece e as rotas daqui recusam.
 *
 * Tudo pelo tenant da sessão. O `state` fica preso a quem começou (empresa e usuário) e vale uma
 * vez, por 10 minutos. As respostas nunca são 401 (o painel trataria como sessão caída).
 */
@Injectable()
export class RegemCliqueService {
  private readonly logger = new Logger('ConectarPeloRegem');
  /** A chamada de rede ao Regem (o pedido e a troca). O teste troca. */
  buscar: typeof fetch = (...a) => fetch(...a);

  constructor(
    private readonly prisma: PrismaService,
    private readonly resolver: RegemConfigResolver,
    private readonly avisos: RegemAvisosService,
  ) {}

  private config(): ConfigDoClique {
    return lerConfigDoClique(process.env);
  }

  get disponivel(): boolean {
    return cliqueDisponivel();
  }

  /** O resumo para o painel (nunca a ligação). */
  situacao(clique: unknown): SituacaoDoClique {
    return { disponivel: this.disponivel, ...resumoDoClique(clique) };
  }

  private exigir(): { c: Ligado; chave: Buffer } {
    const c = this.config();
    const chave = chaveDosSegredos();
    if (!c.ligado || !clienteDmsIdDoGogem() || !chave) {
      throw new ServiceUnavailableException(
        'A conexão pelo Regem ainda não está disponível neste servidor. Use o token de integração ou avise o suporte do GoGeM.',
      );
    }
    return { c, chave };
  }

  /** POST na porta de autorização do Regem com o token do DMS ID; no 401, outro token, uma vez. */
  private async chamar(
    c: Ligado,
    caminho: '/autorizacao/pedido' | '/autorizacao/token',
    corpo: Record<string, string>,
  ): Promise<{ status: number; corpo: unknown }> {
    const dmsId = clienteDmsIdDoGogem();
    if (!dmsId) throw new ServiceUnavailableException(COMECE_DE_NOVO);
    for (let vez = 0; ; vez++) {
      let token: string;
      try {
        token = await dmsId.token();
      } catch (err) {
        this.logger.error(
          `O DMS ID não deu o token para o Regem: ${err instanceof Error ? err.message : String(err)}`,
        );
        throw new ServiceUnavailableException(
          'O GoGeM ainda não está liberado para pedir a conexão ao Regem. Avise o suporte do GoGeM.',
        );
      }
      let r: Response;
      try {
        r = await this.buscar(`${c.recurso}${caminho}`, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${token}`,
            'content-type': 'application/json',
            accept: 'application/json',
          },
          body: JSON.stringify(corpo),
          redirect: 'manual',
          signal: AbortSignal.timeout(15_000),
        });
      } catch {
        throw new ServiceUnavailableException(
          'O Regem não respondeu agora. Tente de novo em instantes.',
        );
      }
      if (r.status === 401 && vez === 0) {
        dmsId.esquecer();
        continue;
      }
      return { status: r.status, corpo: await r.json().catch(() => null) };
    }
  }

  private motivoDoRegem(corpo: unknown): string {
    const d = (corpo as { detail?: unknown; message?: unknown } | null) ?? {};
    return String(d.detail ?? d.message ?? '').slice(0, 200);
  }

  // ───────────────────────────── começar ─────────────────────────────

  /** Empurra o pedido ao Regem e devolve a página para onde o navegador vai. Nada é ligado aqui. */
  async iniciar(quem: QuemConecta): Promise<{ url: string }> {
    const { c, chave } = this.exigir();
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: quem.tenantId },
      select: { nome: true },
    });
    const p = gerarPedido();
    const r = await this.chamar(
      c,
      '/autorizacao/pedido',
      corpoDoPedido({
        volta: c.volta,
        estado: p.estado,
        desafio: p.desafio,
        contaNome: tenant?.nome ?? '',
        contaCnpj: null,
        contaEmail: quem.email,
      }),
    );
    const numero = (r.corpo as { request_uri?: unknown } | null)?.request_uri;
    if (r.status !== 201 || !formatoDoNumero(numero)) {
      // o motivo é para a distribuição (aplicativo fora da lista do Regem, volta não cadastrada...)
      this.logger.error(
        `o Regem recusou o pedido de conexão (${r.status}): ${this.motivoDoRegem(r.corpo)}`,
      );
      if (r.status === 503) {
        throw new ServiceUnavailableException(
          'O Regem está com as integrações pausadas agora. Tente de novo mais tarde.',
        );
      }
      throw new ServiceUnavailableException(
        'O Regem não aceitou abrir a conexão agora. Avise o suporte do GoGeM.',
      );
    }
    const dono = this.dono(quem.tenantId);
    await this.prisma.regemCliquePedido.create({
      data: {
        tenantId: quem.tenantId,
        usuarioId: quem.userId,
        estadoHash: p.estadoHash,
        verificadorCifrado: cifrar(
          p.verificador,
          chave,
          contextoDoSegredo(dono, CAMPO_DO_VERIFICADOR),
        ),
        venceEm: new Date(Date.now() + VALIDADE_DO_PEDIDO_MS),
      },
    });
    // Os pedidos velhos saem aqui (não há rotina para eles), pelo índice do vencimento.
    await this.prisma.regemCliquePedido
      .deleteMany({
        where: { venceEm: { lt: new Date(Date.now() - 24 * 60 * 60_000) } },
      })
      .catch((e: unknown) =>
        this.logger.warn(
          `limpar pedidos de conexão vencidos falhou: ${e instanceof Error ? e.message : String(e)}`,
        ),
      );
    return { url: urlDaPagina(c.pagina, c.aplicativo, numero) };
  }

  private dono(tenantId: string): DonoDoSegredo {
    return { tenantId, unidadeId: null, tipo: 'regem' };
  }

  // ───────────────────────────── concluir ─────────────────────────────

  /**
   * A volta do Regem. Confere o `iss` e o `state`, GASTA o pedido (uma vez só, de quem começou) e,
   * com o código, troca pela ligação de cada loja marcada. Guarda e religa os avisos pela ligação
   * (a troca revogou o token antigo, e o registro ia com ele — G-7). O presidente recusou: nada muda.
   */
  async concluir(
    quem: QuemConecta,
    q: { code?: unknown; state?: unknown; iss?: unknown; error?: unknown },
  ): Promise<
    | { situacao: 'conectado'; clique: SituacaoDoClique; avisos: string }
    | { situacao: 'recusado' }
  > {
    const { c, chave } = this.exigir();
    const v = conferirVolta(q, c.emissorDoRegem);
    if (v.tipo === 'invalida') {
      throw new BadRequestException(
        `Não deu para concluir: ${v.motivo}. ${COMECE_DE_NOVO}`,
      );
    }
    const gasto = await this.prisma.regemCliquePedido.updateMany({
      where: {
        estadoHash: hashDoEstado(v.estado),
        tenantId: quem.tenantId,
        usuarioId: quem.userId,
        usadoEm: null,
        venceEm: { gt: new Date() },
      },
      data: { usadoEm: new Date() },
    });
    const pedido =
      gasto.count === 1
        ? await this.prisma.regemCliquePedido.findUnique({
            where: { estadoHash: hashDoEstado(v.estado) },
          })
        : null;
    if (!pedido) {
      throw new BadRequestException(
        `Este pedido de conexão não vale mais: já foi usado, venceu ou foi aberto por outra pessoa. ${COMECE_DE_NOVO}`,
      );
    }
    if (v.tipo === 'recusa') {
      if (v.motivo === 'recusado') return { situacao: 'recusado' };
      throw new BadRequestException(
        `O Regem não reconheceu o pedido de conexão. ${COMECE_DE_NOVO}`,
      );
    }

    const verificador = decifrar(
      pedido.verificadorCifrado,
      chave,
      contextoDoSegredo(this.dono(quem.tenantId), CAMPO_DO_VERIFICADOR),
    );
    if (!verificador) {
      this.logger.error(
        'o verificador do pedido de conexão não abre com a chave atual',
      );
      throw new ServiceUnavailableException(
        `Não deu para concluir a conexão agora. ${COMECE_DE_NOVO}`,
      );
    }
    const r = await this.chamar(c, '/autorizacao/token', {
      grant_type: 'authorization_code',
      code: v.codigo,
      code_verifier: verificador,
      redirect_uri: c.volta,
    });
    if (r.status !== 200) {
      this.logger.error(
        `o Regem recusou a troca do código (${r.status}): ${this.motivoDoRegem(r.corpo)}`,
      );
      throw new BadRequestException(
        `O Regem não aceitou concluir a conexão. ${COMECE_DE_NOVO}`,
      );
    }
    const lojas = lojasDaTroca(r.corpo);
    if (!lojas) {
      this.logger.error(
        'a troca do código no Regem veio sem loja válida: nada foi guardado',
      );
      throw new ServiceUnavailableException(
        'O Regem respondeu de um jeito que o GoGeM não entendeu. Nada foi guardado; avise o suporte do GoGeM.',
      );
    }

    const linha = await this.guardar(quem, c.base, chave, lojas);
    // Os avisos assinados pela ligação (o cancelamento feito no Regem chega ao totem).
    const cfg = await this.resolver.resolve({ ignoreActive: true });
    const avisos = await this.avisos.garantirRegistro(cfg, { forcar: true });
    return {
      situacao: 'conectado',
      clique: this.situacao(linha.clique),
      avisos: avisos.detalhe,
    };
  }

  /**
   * Guarda a ligação de cada loja (cifrada) e põe uma em uso, na integração Regem da EMPRESA (a
   * que o totem usa). Sem integração, ela nasce ativa, com a base do Regem. Limpa a recusa
   * marcada (a conexão é nova) e o registro dos avisos (preso ao token antigo).
   */
  private async guardar(
    quem: QuemConecta,
    base: string,
    chave: Buffer,
    lojas: LojaLigada[],
  ) {
    const dono = this.dono(quem.tenantId);
    const atual = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem', unidadeId: null },
    });
    const antes = lerClique(atual?.clique ?? null);
    const uso = lojaEmUso(lojas, antes?.emUso);
    const clique: CliqueGuardado = {
      versao: 1,
      base,
      emUso: uso.lojaId,
      lojas: lojas.map((l) => ({
        lojaId: l.lojaId,
        nome: l.nome,
        prefixo: l.prefixo,
        permissoes: l.permissoes,
        ligacao: selarLigacao(dono, l.lojaId, l.ligacao, chave),
      })),
      conectadoEm: new Date().toISOString(),
      conectadoPor: quem.userId,
    };
    const json = clique as unknown as Prisma.InputJsonValue;
    if (!atual) {
      return this.prisma.integracao.create({
        data: {
          tenantId: quem.tenantId,
          unidadeId: null,
          tipo: 'regem',
          ativo: true,
          config: { apiBase: base },
          clique: json,
        },
      });
    }
    const config = (atual.config ?? {}) as Record<string, unknown>;
    return this.prisma.integracao.update({
      where: { id: atual.id },
      data: {
        clique: json,
        ativo: true,
        ultimoTeste: Prisma.DbNull,
        avisos: Prisma.DbNull,
        ...(typeof config.apiBase === 'string' && config.apiBase.trim()
          ? {}
          : { config: { ...config, apiBase: base } as Prisma.InputJsonValue }),
      },
    });
  }

  // ───────────────────────────── a loja em uso ─────────────────────────────

  /** Troca a loja do Regem em uso (só entre as que o presidente ligou a esta empresa). */
  async escolher(lojaId: unknown): Promise<SituacaoDoClique> {
    const id = typeof lojaId === 'string' ? lojaId.trim() : '';
    if (!id || id.length > 100) {
      throw new BadRequestException('Escolha uma loja do Regem da lista.');
    }
    const atual = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem', unidadeId: null },
    });
    const c = lerClique(atual?.clique ?? null);
    if (!atual || !c || !c.lojas.some((l) => l.lojaId === id)) {
      throw new BadRequestException(
        'Essa loja do Regem não está ligada a esta empresa.',
      );
    }
    const novo = { ...c, emUso: id } as unknown as Prisma.InputJsonValue;
    const linha = await this.prisma.integracao.update({
      where: { id: atual.id },
      data: { clique: novo, ultimoTeste: Prisma.DbNull, avisos: Prisma.DbNull },
    });
    // O aviso é preso à ligação: a loja nova registra o dela.
    const cfg = await this.resolver.resolve({ ignoreActive: true });
    await this.avisos.garantirRegistro(cfg, { forcar: true });
    return this.situacao(linha.clique);
  }
}
