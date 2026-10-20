import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { segredoDa, type LinhaComSegredo } from '../../integracao/segredos';
import { ultimoTesteDaRecusa } from './chamada-regem';

/** O Regem recusou o token de integração da loja e ninguém reconectou ainda. */
export interface CredencialRecusada {
  status: number;
  detalhe: string;
  em: string;
}

/** Config resolvida do conector Regem para o tenant do contexto. */
export interface RegemConfig {
  base: string;
  /** Token de sincronização (`X-Sync-Token`) — o caminho de sempre. */
  token: string;
  /** Token de integração (`rgm_it_…`): com ele, só `Authorization: Bearer`. */
  tokenIntegracao?: string | null;
  /** A linha da integração (marca a recusa do token novo). */
  integracaoId?: string | null;
  /** Recusa do token novo ainda não resolvida (as chamadas não vão ao Regem). */
  credencialRecusada?: CredencialRecusada | null;
}

/**
 * RegemConfigResolver — resolve a config do Regem PARA O TENANT ATUAL.
 *
 * Precedência: a integração DA LOJA do contexto e, depois, a da EMPRESA — a linha
 * `Integracao(tipo='regem')` do tenant (escopada pelo middleware do Prisma), `ativo` e com
 * `apiBase`+`token` em `config`. Sem ela → erro claro (a venda/o import falham com mensagem
 * acionável, não com 500 opaco).
 *
 * NÃO existe mais o "Regem padrão" das envs (`REGEM_API_BASE`/`REGEM_SYNC_TOKEN`), herança do
 * piloto de uma loja só: com ele, a empresa SEM integração mandava venda e baixava cardápio do
 * Regem de OUTRA empresa, com resposta de sucesso (ERR-012). Cada empresa pareia o seu Regem.
 *
 * Os tokens vêm cifrados do banco (`segredoDa` abre; valor antigo em claro passa como está).
 * O token de integração é opcional: sem ele, vale o token de sincronização (ver `chamada-regem.ts`).
 */
@Injectable()
export class RegemConfigResolver {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * `ignoreActive` (usado pelo "testar conexão") considera a integração mesmo
   * quando ainda não foi ativada.
   */
  async resolve(opts?: {
    ignoreActive?: boolean;
    unidadeId?: string | null;
  }): Promise<RegemConfig> {
    const ignoreActive = opts?.ignoreActive ?? false;
    const extrair = (
      row:
        | (LinhaComSegredo & {
            id: string;
            ativo: boolean;
            ultimoTeste: Prisma.JsonValue | null;
          })
        | null,
    ): RegemConfig | null => {
      if (!row || !(ignoreActive || row.ativo)) return null;
      const cfg = (row.config ?? {}) as { apiBase?: string };
      const base = (cfg.apiBase ?? '').trim();
      if (!base) return null;
      const token = segredoDa(row, 'token');
      if (!token) return null;
      const tokenIntegracao = segredoDa(row, 'tokenIntegracao') || null;
      return {
        base,
        token,
        tokenIntegracao,
        integracaoId: row.id,
        credencialRecusada: tokenIntegracao
          ? recusaDoUltimoTeste(row.ultimoTeste)
          : null,
      };
    };

    // Precedência: (1) integração DA LOJA do contexto → (2) nível empresa
    // (unidadeId NULL). Tenant-scoped pelo middleware.
    if (opts?.unidadeId) {
      const loja = await this.prisma.integracao.findFirst({
        where: { tipo: 'regem', unidadeId: opts.unidadeId },
      });
      const cfg = extrair(loja);
      if (cfg) return cfg;
    }

    const empresa = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem', unidadeId: null },
    });
    const cfgEmpresa = extrair(empresa);
    if (cfgEmpresa) return cfgEmpresa;

    throw new Error(
      'Integração Regem não configurada para esta loja: preencha e ative a ' +
        'integração Regem (apiBase + token) na loja ou na empresa.',
    );
  }

  /**
   * Marca que o Regem recusou o token de integração: vai para o "último teste" da integração
   * (o painel mostra o que fazer) e segura as chamadas seguintes até reconectar.
   */
  async marcarCredencialRecusada(
    cfg: RegemConfig,
    status: number,
    detalhe: string,
  ): Promise<void> {
    if (!cfg.integracaoId) return;
    await this.prisma.integracao.update({
      where: { id: cfg.integracaoId },
      data: {
        ultimoTeste: ultimoTesteDaRecusa(
          status,
          detalhe,
        ) as unknown as Prisma.InputJsonValue,
      },
    });
  }
}

/** A recusa guardada no último teste, se houver uma. */
export function recusaDoUltimoTeste(
  ultimoTeste: Prisma.JsonValue | null | undefined,
): CredencialRecusada | null {
  const r = (ultimoTeste as { credencialRecusada?: unknown } | null)
    ?.credencialRecusada as Partial<CredencialRecusada> | undefined;
  if (!r || typeof r !== 'object') return null;
  return {
    status: typeof r.status === 'number' ? r.status : 401,
    detalhe: typeof r.detalhe === 'string' ? r.detalhe : '',
    em: typeof r.em === 'string' ? r.em : '',
  };
}
