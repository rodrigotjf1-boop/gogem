import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/** Config resolvida do conector Regem para o tenant do contexto. */
export interface RegemConfig {
  base: string;
  token: string;
}

/**
 * RegemConfigResolver — resolve `{ base, token }` do Regem PARA O TENANT ATUAL.
 *
 * Precedência: a integração DA LOJA do contexto e, depois, a da EMPRESA — a linha
 * `Integracao(tipo='regem')` do tenant (escopada pelo middleware do Prisma), `ativo` e com
 * `apiBase`+`token` em `config`. Sem ela → erro claro (a venda/o import falham com mensagem
 * acionável, não com 500 opaco).
 *
 * NÃO existe mais o "Regem padrão" das envs (`REGEM_API_BASE`/`REGEM_SYNC_TOKEN`), herança do
 * piloto de uma loja só: com ele, a empresa SEM integração mandava venda e baixava cardápio do
 * Regem de OUTRA empresa, com resposta de sucesso (ERR-012). Cada empresa pareia o seu Regem.
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
      row: { ativo: boolean; config: unknown } | null,
    ): RegemConfig | null => {
      if (!row || !(ignoreActive || row.ativo)) return null;
      const cfg = (row.config ?? {}) as { apiBase?: string; token?: string };
      const base = (cfg.apiBase ?? '').trim();
      const token = (cfg.token ?? '').trim();
      return base && token ? { base, token } : null;
    };

    // Precedência: (1) integração DA LOJA do contexto → (2) nível empresa
    // (unidadeId NULL) → (3) envs globais (piloto). Tenant-scoped pelo middleware.
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
}
