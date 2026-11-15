import { Logger } from '@nestjs/common';

import { cifrar, decifrar } from '../../common/cifra';
import {
  contextoDoSegredo,
  SegredoIlegivelException,
  type DonoDoSegredo,
} from '../../integracao/segredos';

/**
 * A CONEXÃO PELO CLIQUE guardada na integração Regem (coluna `integracoes.clique`, migration
 * `20261115000000_regem_clique`): a ligação de cada loja que o presidente marcou, CIFRADA (o
 * contexto da cifra leva a empresa e a loja do Regem), e a loja em uso. É da distribuição, como os
 * avisos: não vai ao painel nem entra na `config` que o lojista edita. NULL = sem clique (vale o
 * token colado de antes).
 */
export type LojaGuardada = {
  lojaId: string;
  nome: string;
  prefixo: string | null;
  permissoes: string[];
  /** A ligação `dms_lg_regem_…`, cifrada (`v1.…`). */
  ligacao: string;
};

export type CliqueGuardado = {
  versao: 1;
  /** A API do Regem (com o `/api/v1`) em que a ligação vale. */
  base: string;
  emUso: string;
  lojas: LojaGuardada[];
  conectadoEm: string;
  conectadoPor: string | null;
};

const logger = new Logger('CliqueDoRegem');

const contexto = (dono: DonoDoSegredo, lojaId: string) =>
  contextoDoSegredo(dono, `clique:${lojaId}`);

/** O que está na coluna, conferido; torto = `null` (como se não houvesse clique). */
export function lerClique(bruto: unknown): CliqueGuardado | null {
  const c = bruto as Partial<CliqueGuardado> | null | undefined;
  if (!c || typeof c !== 'object' || c.versao !== 1) return null;
  if (typeof c.base !== 'string' || typeof c.emUso !== 'string') return null;
  if (!Array.isArray(c.lojas) || !c.lojas.length) return null;
  const lojas = c.lojas.filter(
    (l): l is LojaGuardada =>
      !!l &&
      typeof l.lojaId === 'string' &&
      typeof l.ligacao === 'string' &&
      typeof l.nome === 'string',
  );
  if (!lojas.length) return null;
  return {
    versao: 1,
    base: c.base,
    emUso: c.emUso,
    lojas,
    conectadoEm: typeof c.conectadoEm === 'string' ? c.conectadoEm : '',
    conectadoPor: typeof c.conectadoPor === 'string' ? c.conectadoPor : null,
  };
}

/** A ligação da loja, cifrada para guardar. */
export function selarLigacao(
  dono: DonoDoSegredo,
  lojaId: string,
  ligacao: string,
  chave: Buffer,
): string {
  return cifrar(ligacao, chave, contexto(dono, lojaId));
}

/**
 * A ligação da loja em uso, aberta, para chamar o Regem. Sem clique (ou sem a loja em uso entre
 * as guardadas) = `null`. Cifra que não abre = 503 com o motivo no log (nunca o valor).
 */
export function ligacaoEmUso(
  linha: DonoDoSegredo & { clique?: unknown },
  chave: Buffer | null,
): { base: string; ligacao: string; lojaId: string; nome: string } | null {
  const c = lerClique(linha.clique);
  if (!c) return null;
  const loja = c.lojas.find((l) => l.lojaId === c.emUso);
  if (!loja) return null;
  const claro = chave
    ? decifrar(loja.ligacao, chave, contexto(linha, loja.lojaId))
    : null;
  if (claro === null) {
    logger.error(
      `A ligação do Regem (loja ${loja.lojaId}) da empresa ${linha.tenantId} ` +
        (chave
          ? 'não abre com a chave atual.'
          : 'está cifrada e a chave não está definida.'),
    );
    throw new SegredoIlegivelException();
  }
  return { base: c.base, ligacao: claro, lojaId: loja.lojaId, nome: loja.nome };
}

/** O resumo para o painel: nunca a ligação, só as lojas e a em uso. */
export function resumoDoClique(bruto: unknown): {
  conectado: boolean;
  emUso: { id: string; nome: string } | null;
  lojas: { id: string; nome: string }[];
  conectadoEm: string | null;
} {
  const c = lerClique(bruto);
  if (!c)
    return { conectado: false, emUso: null, lojas: [], conectadoEm: null };
  const uso = c.lojas.find((l) => l.lojaId === c.emUso) ?? null;
  return {
    conectado: true,
    emUso: uso ? { id: uso.lojaId, nome: uso.nome } : null,
    lojas: c.lojas.map((l) => ({ id: l.lojaId, nome: l.nome })),
    conectadoEm: c.conectadoEm || null,
  };
}
