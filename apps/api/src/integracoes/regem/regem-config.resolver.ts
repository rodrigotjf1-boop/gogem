import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';

/** Config resolvida do conector Regem para o tenant do contexto. */
export interface RegemConfig {
  base: string;
  token: string;
}

/**
 * RegemConfigResolver — resolve `{ base, token }` do Regem PARA O TENANT ATUAL.
 *
 * Precedência (Fase 2): a linha `Integracao(tipo='regem')` do tenant (escopada
 * pelo middleware do Prisma) vence quando está `ativo` e traz `apiBase`+`token`
 * em `config`. Caso contrário cai no fallback das envs globais
 * (`REGEM_API_BASE`/`REGEM_SYNC_TOKEN`) — que mantém o piloto de 1 loja
 * funcionando. Sem nenhum dos dois → erro claro (a venda/o import falham com
 * mensagem acionável, não com 500 opaco).
 *
 * Assim o GoGeM deixa de ser mono-tenant: cada loja pareia o seu Regem.
 */
@Injectable()
export class RegemConfigResolver {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /**
   * `ignoreActive` (usado pelo "testar conexão") considera a integração mesmo
   * quando ainda não foi ativada.
   */
  async resolve(opts?: { ignoreActive?: boolean }): Promise<RegemConfig> {
    // Tenant-scoped: o middleware injeta o tenant do contexto.
    const row = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem' },
    });
    if (row && (opts?.ignoreActive || row.ativo)) {
      const cfg = (row.config ?? {}) as { apiBase?: string; token?: string };
      const base = (cfg.apiBase ?? '').trim();
      const token = (cfg.token ?? '').trim();
      if (base && token) return { base, token };
    }

    // Fallback do piloto: envs globais.
    const base = this.config.get<string>('REGEM_API_BASE')?.trim();
    const token = this.config.get<string>('REGEM_SYNC_TOKEN')?.trim();
    if (base && token) return { base, token };

    throw new Error(
      'Integração Regem não configurada para este tenant: preencha e ative a ' +
        'integração Regem (apiBase + token) ou defina REGEM_API_BASE e ' +
        'REGEM_SYNC_TOKEN no ambiente.',
    );
  }
}
