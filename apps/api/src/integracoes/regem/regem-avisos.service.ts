import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantContext } from '../../tenant/tenant-context';
import { cifrar, decifrar } from '../../common/cifra';
import {
  buscaDoSegredo,
  chaveDosSegredos,
  contextoDoSegredo,
  type DonoDoSegredo,
} from '../../integracao/segredos';
import { chamarRegem, mensagemDoRegem } from './chamada-regem';
import { RegemConfigResolver, type RegemConfig } from './regem-config.resolver';
import {
  CAMPO_DO_SEGREDO,
  ESPERA_ENTRE_TENTATIVAS_MS,
  ID_DO_ENDERECO,
  JANELA_DO_ANTERIOR_MS,
  REGISTRAR_DE_NOVO_MS,
  chaveDoSegredo,
  conferirAvisoAssinado,
  enderecoDosAvisos,
  lerEstadoDosAvisos,
  novoSegredoDosAvisos,
  type EstadoDosAvisos,
} from './avisos-regem';

/** O que o painel e o "Testar conexão" mostram dos avisos (nunca o segredo). */
export interface SituacaoDosAvisos {
  ligados: boolean;
  registradoEm: string | null;
  erro: string | null;
  /** Uma frase para o painel. */
  detalhe: string;
}

/** Um aviso que passou na conferência (§3): de qual empresa e o corpo já lido. */
export interface AvisoConferido {
  tenantId: string;
  corpo: { tipo?: unknown; contrato?: unknown; [k: string]: unknown };
}

/** Prazo da chamada de registro/desligamento ao Regem (ms). */
const PRAZO_MS = 10_000;

/**
 * Os AVISOS ASSINADOS do Regem ao GoGeM (contrato 1, `AVISOS-ASSINADOS.md` do Regem):
 *  • REGISTRAR — com o token de integração da loja, `PUT /integracao/webhook` com o endereço
 *    desta integração e um segredo `whsec_` que o GoGeM gera e guarda cifrado. O segredo é gravado
 *    ANTES de ir ao Regem: ao registrar, o cancelamento que estava parado sai na hora, e tem de
 *    conferir. Só o "Testar conexão" liga pela primeira vez (decisão do dono, 19/10/2026); a rotina
 *    de 5 min só RELIGA uma vez por dia o que já está ligado com o mesmo token;
 *  • DESLIGAR — `DELETE /integracao/webhook`; o Regem volta ao caminho antigo na hora;
 *  • CONFERIR — o aviso que chega, na ordem do §3: integração, relógio, assinatura, contrato.
 *
 * O registro é dado da distribuição (coluna `avisos`), não da config que o lojista edita.
 */
@Injectable()
export class RegemAvisosService {
  private readonly logger = new Logger(RegemAvisosService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly resolver: RegemConfigResolver,
  ) {}

  /** A situação a partir da coluna (sem abrir segredo nenhum). */
  situacao(avisos: unknown): SituacaoDosAvisos {
    const e = lerEstadoDosAvisos(avisos);
    const ligados = Boolean(e?.registradoEm);
    const erro = e?.erro ?? null;
    let detalhe: string;
    if (ligados && !erro) {
      detalhe = 'Avisos do Regem: ligados (assinados).';
    } else if (ligados && erro) {
      detalhe = `Avisos do Regem: ligados; a última religação não passou — ${erro}`;
    } else if (erro) {
      detalhe = `Avisos do Regem: não ligados — ${erro}`;
    } else {
      detalhe =
        'Avisos do Regem: não ligados (o Regem avisa pelo caminho antigo).';
    }
    return { ligados, registradoEm: e?.registradoEm ?? null, erro, detalhe };
  }

  /**
   * Liga (ou religa) os avisos desta integração no Regem. Nunca rejeita: devolve a situação.
   * `forcar` = "Testar conexão" (registra agora). `soReativar` = a rotina de 5 min: só religa o
   * que já está ligado com este token, uma vez a cada 20 h, e espera 30 min depois de uma falha.
   */
  async garantirRegistro(
    cfg: RegemConfig,
    opts: { forcar?: boolean; soReativar?: boolean } = {},
  ): Promise<SituacaoDosAvisos> {
    try {
      return await this.registrar(cfg, opts);
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      this.logger.error(`Registro dos avisos do Regem falhou: ${motivo}`);
      return {
        ligados: false,
        registradoEm: null,
        erro: motivo,
        detalhe: `Avisos do Regem: não ligados — ${motivo}`,
      };
    }
  }

  private async registrar(
    cfg: RegemConfig,
    opts: { forcar?: boolean; soReativar?: boolean },
  ): Promise<SituacaoDosAvisos> {
    if (!cfg.tokenIntegracao || !cfg.integracaoId) {
      return this.situacao(null);
    }
    const chave = chaveDosSegredos();
    if (!chave) {
      return {
        ...this.situacao(null),
        erro: 'o servidor ainda não tem a chave dos segredos',
        detalhe:
          'Avisos do Regem: não ligados — o servidor ainda não está pronto para guardar o segredo dos avisos.',
      };
    }
    const linha = await this.prisma.integracao.findFirst({
      where: { id: cfg.integracaoId },
      select: {
        id: true,
        tenantId: true,
        unidadeId: true,
        tipo: true,
        avisos: true,
      },
    });
    if (!linha) return this.situacao(null);

    const dono: DonoDoSegredo = {
      tenantId: linha.tenantId,
      unidadeId: linha.unidadeId,
      tipo: linha.tipo,
    };
    const contexto = contextoDoSegredo(dono, CAMPO_DO_SEGREDO);
    const estado = lerEstadoDosAvisos(linha.avisos);
    const resumo = buscaDoSegredo(cfg.tokenIntegracao);
    const mesmoToken = estado?.resumoDoToken === resumo;
    const agora = Date.now();
    const agoraIso = new Date(agora).toISOString();

    if (opts.soReativar && !opts.forcar) {
      if (!estado?.registradoEm || !mesmoToken)
        return this.situacao(linha.avisos);
      if (agora - Date.parse(estado.registradoEm) < REGISTRAR_DE_NOVO_MS) {
        return this.situacao(linha.avisos);
      }
      if (
        estado.tentadoEm &&
        agora - Date.parse(estado.tentadoEm) < ESPERA_ENTRE_TENTATIVAS_MS
      ) {
        return this.situacao(linha.avisos);
      }
    }

    // O segredo: o mesmo enquanto o token for o mesmo (religar não troca); token novo = segredo
    // novo, e o anterior vale por mais 10 min (um aviso que já estava saindo).
    const atual =
      mesmoToken && estado ? decifrar(estado.segredo, chave, contexto) : null;
    let segredo: string;
    let novo: EstadoDosAvisos;
    if (atual && chaveDoSegredo(atual) && estado) {
      segredo = atual;
      novo = { ...estado, tentadoEm: agoraIso };
    } else {
      segredo = novoSegredoDosAvisos();
      novo = {
        segredo: cifrar(segredo, chave, contexto),
        anterior: estado?.segredo ?? null,
        trocadoEm: estado?.segredo ? agoraIso : null,
        resumoDoToken: resumo,
        registradoEm: null,
        tentadoEm: agoraIso,
        erro: null,
      };
    }

    // Grava ANTES de ir ao Regem, e só se ninguém mexeu desde a leitura (o "Testar conexão" e a
    // rotina de 5 min não trocam o segredo um do outro).
    const gravou = await this.prisma.integracao.updateMany({
      where: {
        id: linha.id,
        avisos:
          linha.avisos === null
            ? { equals: Prisma.AnyNull }
            : { equals: linha.avisos as Prisma.InputJsonValue },
      },
      data: { avisos: novo as unknown as Prisma.InputJsonValue },
    });
    if (gravou.count !== 1) {
      return {
        ...this.situacao(linha.avisos),
        detalhe:
          'Avisos do Regem: outro registro está em andamento; teste de novo em instantes.',
      };
    }

    let resultado: EstadoDosAvisos;
    try {
      const res = await chamarRegem(this.resolver, cfg, {
        caminho: '/integracao/webhook',
        metodo: 'PUT',
        corpo: { url: enderecoDosAvisos(linha.id), segredo },
        prazoMs: PRAZO_MS,
        rotulo: 'o registro dos avisos',
        marcarRecusa: false,
      });
      if (res.ok) {
        resultado = {
          ...novo,
          registradoEm: new Date().toISOString(),
          erro: null,
        };
      } else {
        const det = mensagemDoRegem(await res.text().catch(() => ''));
        resultado = {
          ...novo,
          erro: `o Regem respondeu ${res.status}: ${det}`,
        };
      }
    } catch (err) {
      resultado = {
        ...novo,
        erro: err instanceof Error ? err.message : String(err),
      };
    }
    await this.prisma.integracao.update({
      where: { id: linha.id },
      data: { avisos: resultado as unknown as Prisma.InputJsonValue },
    });
    if (resultado.erro) {
      this.logger.warn(
        `Avisos do Regem não ligados (integração ${linha.id}): ${resultado.erro}`,
      );
    }
    return this.situacao(resultado);
  }

  /**
   * Desliga os avisos: `DELETE` no Regem e, só se ele confirmar (204, ou 404 = já não havia),
   * apaga o registro daqui. Se o Regem não confirmar, o registro fica: apagar só daqui faria o
   * Regem seguir assinando para um endereço que passaria a recusar (401 = ele espera 6 h).
   */
  async desligar(cfg: RegemConfig): Promise<SituacaoDosAvisos> {
    if (!cfg.integracaoId) return this.situacao(null);
    const linha = await this.prisma.integracao.findFirst({
      where: { id: cfg.integracaoId },
      select: { id: true, avisos: true },
    });
    if (!linha) return this.situacao(null);
    if (!cfg.tokenIntegracao) {
      return {
        ...this.situacao(linha.avisos),
        detalhe:
          'Avisos do Regem: para desligar é preciso o token de integração da loja (o registro é preso a ele).',
      };
    }
    try {
      const res = await chamarRegem(this.resolver, cfg, {
        caminho: '/integracao/webhook',
        metodo: 'DELETE',
        prazoMs: PRAZO_MS,
        rotulo: 'o desligamento dos avisos',
        marcarRecusa: false,
      });
      if (!res.ok && res.status !== 404) {
        const det = mensagemDoRegem(await res.text().catch(() => ''));
        return {
          ...this.situacao(linha.avisos),
          detalhe: `Avisos do Regem: não desligados — o Regem respondeu ${res.status}: ${det}`,
        };
      }
    } catch (err) {
      return {
        ...this.situacao(linha.avisos),
        detalhe: `Avisos do Regem: não desligados — ${err instanceof Error ? err.message : String(err)}`,
      };
    }
    await this.prisma.integracao.update({
      where: { id: linha.id },
      data: { avisos: Prisma.DbNull },
    });
    return {
      ligados: false,
      registradoEm: null,
      erro: null,
      detalhe: 'Avisos do Regem desligados: o Regem voltou ao caminho antigo.',
    };
  }

  /**
   * Confere o aviso que chegou, na ordem do §3 do contrato. Lança 401 (integração, relógio,
   * assinatura), 400 (corpo que não é JSON) ou 422 (contrato). Nada de segredo no log.
   */
  async conferir(
    integracaoId: string,
    cabecalhos: Record<string, string | string[] | undefined>,
    corpoCru: string,
    agora: Date = new Date(),
  ): Promise<AvisoConferido> {
    const recusa = (motivo: string, extra = '') => {
      this.logger.warn(
        `Aviso do Regem recusado (integração ${integracaoId.slice(0, 64)}): ${motivo}${extra}`,
      );
      return new UnauthorizedException('Aviso sem assinatura válida.');
    };
    if (!ID_DO_ENDERECO.test(integracaoId)) throw recusa('endereço inválido');

    // 1. A integração pelo trecho do endereço (sem tenant no contexto: a assinatura é a prova).
    const linha = await TenantContext.runAsSystem(async () => {
      const l = await this.prisma.integracao.findFirst({
        where: { id: integracaoId, tipo: 'regem' },
        select: {
          id: true,
          tenantId: true,
          unidadeId: true,
          tipo: true,
          ativo: true,
          avisos: true,
        },
      });
      return l;
    });
    if (!linha || !linha.ativo)
      throw recusa('integração não encontrada ou desligada');
    const estado = lerEstadoDosAvisos(linha.avisos);
    const chave = chaveDosSegredos();
    if (!estado || !chave) throw recusa('avisos não ligados nesta integração');

    const contexto = contextoDoSegredo(
      {
        tenantId: linha.tenantId,
        unidadeId: linha.unidadeId,
        tipo: linha.tipo,
      },
      CAMPO_DO_SEGREDO,
    );
    const chaves: Buffer[] = [];
    const atual = chaveDoSegredo(decifrar(estado.segredo, chave, contexto));
    if (atual) chaves.push(atual);
    if (
      estado.anterior &&
      estado.trocadoEm &&
      agora.getTime() - Date.parse(estado.trocadoEm) <= JANELA_DO_ANTERIOR_MS
    ) {
      const anterior = chaveDoSegredo(
        decifrar(estado.anterior, chave, contexto),
      );
      if (anterior) chaves.push(anterior);
    }
    if (!chaves.length) throw recusa('o segredo guardado não abre');

    // 2 e 3. O relógio e a assinatura, sobre o corpo exato.
    const um = (v: string | string[] | undefined) =>
      Array.isArray(v) ? v[0] : v;
    const conferencia = conferirAvisoAssinado({
      id: um(cabecalhos['webhook-id']),
      timestamp: um(cabecalhos['webhook-timestamp']),
      assinatura: um(cabecalhos['webhook-signature']),
      corpo: corpoCru,
      chaves,
      agora,
    });
    if (conferencia !== 'ok') throw recusa(conferencia);

    // 4. O contrato.
    let corpo: AvisoConferido['corpo'];
    try {
      corpo = JSON.parse(corpoCru) as AvisoConferido['corpo'];
    } catch {
      throw new BadRequestException('O corpo do aviso não é JSON.');
    }
    if (!corpo || typeof corpo !== 'object' || corpo.contrato !== 1) {
      throw new UnprocessableEntityException({
        code: 'contrato-nao-suportado',
        message: `O GoGeM atende o contrato 1 dos avisos; chegou ${JSON.stringify(corpo?.contrato ?? null)}.`,
      });
    }
    // 5. A loja do Regem: a integração do GoGeM não guarda a loja do Regem (a assinatura já
    // prende o aviso a esta integração) — a segunda trava do §3.5 não se aplica.
    return { tenantId: linha.tenantId, corpo };
  }
}
