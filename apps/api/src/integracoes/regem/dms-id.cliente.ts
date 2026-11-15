import { Logger } from '@nestjs/common';

import { lerConfigDoClique, PERMISSOES_DO_TOTEM } from './regem-clique.regras';

/**
 * O TOKEN DO DMS ID do GoGeM para o Regem (Hub DMS, F6, plano "Clique GoGeM → Regem"): o
 * aplicativo do GoGeM no DMS ID pede o token por `client_credentials`, com o recurso do Regem e
 * as permissões do totem, e o guarda até perto de vencer. Pedidos ao mesmo tempo viram UM pedido
 * ao DMS ID. O Regem respondeu 401 a uma ligação? `esquecer` e pedir de novo, uma vez (quem chama
 * decide). O segredo do aplicativo fica só na configuração do servidor; nunca em log nem erro.
 */
export class ErroDoDmsId extends Error {
  constructor(
    readonly status: number,
    motivo: string,
  ) {
    super(`O DMS ID não deu o token (${status || 'sem resposta'}): ${motivo}`);
    this.name = 'ErroDoDmsId';
  }
}

type Guardado = { chave: string; token: string; venceEm: number };

const MARGEM_MS = 60_000;
const PRAZO_MS = 10_000;

export class ClienteDmsId {
  private guardado: Guardado | null = null;
  private emCurso: { chave: string; pedido: Promise<string> } | null = null;

  constructor(
    private readonly o: {
      emissor: string;
      aplicativo: string;
      segredo: string;
      recurso: string;
      buscar?: typeof fetch;
      relogio?: () => number;
    },
  ) {}

  private get chave(): string {
    return `${this.o.emissor}\n${this.o.aplicativo}\n${this.o.recurso}`;
  }

  private agora(): number {
    return this.o.relogio ? this.o.relogio() : Date.now();
  }

  async token(): Promise<string> {
    const g = this.guardado;
    if (g && g.chave === this.chave && g.venceEm - MARGEM_MS > this.agora()) {
      return g.token;
    }
    if (this.emCurso?.chave === this.chave) return this.emCurso.pedido;
    const pedido = this.pedir().finally(() => {
      this.emCurso = null;
    });
    this.emCurso = { chave: this.chave, pedido };
    return pedido;
  }

  esquecer(): void {
    this.guardado = null;
  }

  private async pedir(): Promise<string> {
    const buscar = this.o.buscar ?? fetch;
    // RFC 6749 §2.3.1: o id e o segredo vão codificados antes do Basic.
    const credencial = Buffer.from(
      `${encodeURIComponent(this.o.aplicativo)}:${encodeURIComponent(this.o.segredo)}`,
    ).toString('base64');
    let r: Response;
    try {
      r = await buscar(`${this.o.emissor}/token`, {
        method: 'POST',
        headers: {
          authorization: `Basic ${credencial}`,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'client_credentials',
          resource: this.o.recurso,
          scope: PERMISSOES_DO_TOTEM.join(' '),
        }).toString(),
        signal: AbortSignal.timeout(PRAZO_MS),
      });
    } catch {
      throw new ErroDoDmsId(0, 'sem resposta');
    }
    const corpo = (await r.json().catch(() => ({}))) as {
      access_token?: unknown;
      expires_in?: unknown;
      error?: unknown;
    };
    if (!r.ok || typeof corpo.access_token !== 'string') {
      throw new ErroDoDmsId(
        r.status,
        typeof corpo.error === 'string' ? corpo.error.slice(0, 60) : 'recusado',
      );
    }
    const segundos =
      typeof corpo.expires_in === 'number' && corpo.expires_in > 0
        ? corpo.expires_in
        : 300;
    this.guardado = {
      chave: this.chave,
      token: corpo.access_token,
      venceEm: this.agora() + segundos * 1000,
    };
    return corpo.access_token;
  }
}

const logger = new Logger('DmsIdDoGogem');
let lido: { chave: string; cliente: ClienteDmsId | null } | null = null;

/**
 * O cliente do DMS ID desta API, montado da configuração do clique (relido só quando o ambiente
 * muda). `null` = o "Conectar pelo Regem" está desligado ou torto (o motivo vai ao log uma vez).
 */
export function clienteDmsIdDoGogem(
  env: Record<string, string | undefined> = process.env,
): ClienteDmsId | null {
  const chave = [
    env.GOGEM_REGEM_CLIQUE,
    env.GOGEM_REGEM_API_URL,
    env.GOGEM_REGEM_APP_URL,
    env.GOGEM_PAINEL_URL,
    env.DMS_ID_EMISSOR,
    env.DMS_ID_APLICATIVO,
    env.DMS_ID_SEGREDO,
  ].join('\n');
  if (lido?.chave !== chave) {
    const c = lerConfigDoClique(env);
    if (!c.ligado && c.motivo) {
      logger.error(`"Conectar pelo Regem" desligado: ${c.motivo}`);
    }
    lido = {
      chave,
      cliente: c.ligado
        ? new ClienteDmsId({
            emissor: c.emissorDmsId,
            aplicativo: c.aplicativo,
            segredo: c.segredo,
            recurso: c.recurso,
          })
        : null,
    };
  }
  return lido.cliente;
}

/** Só para os testes: esquece o cliente montado (o próximo relê o ambiente). */
export function esquecerClienteDmsId(): void {
  lido = null;
}
