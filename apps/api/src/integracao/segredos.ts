import { createHash } from 'node:crypto';
import { Logger, ServiceUnavailableException } from '@nestjs/common';
import { cifrar, decifrar, ehCifrado, lerChave } from '../common/cifra';
import type { Conector } from './conectores';

/**
 * Segredos das integrações (token do Regem, access token do Mercado Pago,
 * client secret do Open Delivery) guardados CIFRADOS em `Integracao.config`.
 *
 * - A chave vem da env `GOGEM_CHAVE_DOS_SEGREDOS` (32 bytes em base64), que só a
 *   distribuição conhece; ela nunca vai para o banco nem para o código.
 * - O contexto da cifra amarra o texto à empresa, à loja, ao conector e ao
 *   campo: copiar o valor para outra linha não abre.
 * - Valor ainda em claro (gravado antes da cifra) é lido como está; a migração
 *   do boot (`SegredosMigracao`) cifra o que encontrar assim.
 * - O campo marcado `busca` (o token do Regem) também guarda o SHA-256 em
 *   `Integracao.segredoBusca`: é por ele que a entrada do Regem acha a empresa
 *   sem precisar abrir a cifra de todas as linhas.
 */

export const ENV_CHAVE_DOS_SEGREDOS = 'GOGEM_CHAVE_DOS_SEGREDOS';

const logger = new Logger('SegredosDasIntegracoes');

/** De quem é o segredo: a linha de `Integracao` (empresa, loja, conector). */
export interface DonoDoSegredo {
  tenantId: string;
  unidadeId: string | null;
  tipo: string;
}

/** Linha de `Integracao` com o que a leitura de um segredo precisa. */
export interface LinhaComSegredo extends DonoDoSegredo {
  config: unknown;
}

/** A chave da env, ou null quando ausente ou em formato errado. */
export function chaveDosSegredos(): Buffer | null {
  return lerChave(process.env[ENV_CHAVE_DOS_SEGREDOS]);
}

/** Dado associado da cifra: o texto só abre na mesma linha e no mesmo campo. */
export function contextoDoSegredo(dono: DonoDoSegredo, campo: string): string {
  return [
    'gogem',
    'integracao',
    dono.tenantId,
    dono.unidadeId ?? 'empresa',
    dono.tipo,
    campo,
  ].join(':');
}

/** Resumo de busca do segredo (SHA-256 em hexadecimal do valor sem espaços). */
export function buscaDoSegredo(claro: string): string {
  return createHash('sha256').update(claro.trim(), 'utf8').digest('hex');
}

/**
 * O segredo está cifrado e não abre (chave ausente, trocada ou texto
 * adulterado). Não se trata como "não configurado": cair no caminho de quem
 * não tem integração mandaria a venda para o lugar errado.
 */
export class SegredoIlegivelException extends ServiceUnavailableException {
  constructor() {
    super(
      'Não foi possível ler a credencial guardada desta integração. ' +
        'Avise o suporte do GoGeM.',
    );
  }
}

/** O servidor não tem a chave e recebeu um segredo novo para guardar. */
export class SemChaveDosSegredosException extends ServiceUnavailableException {
  constructor() {
    super(
      'O servidor ainda não está pronto para guardar credenciais novas. ' +
        'Nada foi alterado — avise o suporte do GoGeM.',
    );
  }
}

/**
 * Valor de um campo-segredo da linha, em claro. Linha ou campo ausente = ''.
 * Valor legado em claro passa como está. Cifrado que não abre → exceção.
 */
export function segredoDa(
  linha: LinhaComSegredo | null | undefined,
  campo: string,
  chave: Buffer | null = chaveDosSegredos(),
): string {
  if (!linha) return '';
  const guardado = (linha.config as Record<string, unknown> | null)?.[campo];
  if (typeof guardado !== 'string') return '';
  if (!ehCifrado(guardado)) return guardado.trim();
  const claro = chave
    ? decifrar(guardado, chave, contextoDoSegredo(linha, campo))
    : null;
  if (claro === null) {
    // Só o motivo, nunca o valor (V11: o 5xx deixa rastro local).
    logger.error(
      `Segredo "${campo}" da integração ${linha.tipo} (empresa ${linha.tenantId}) ` +
        (chave
          ? 'não abre com a chave atual.'
          : `está cifrado e a ${ENV_CHAVE_DOS_SEGREDOS} não está definida.`),
    );
    throw new SegredoIlegivelException();
  }
  return claro.trim();
}

/** Resultado de selar uma config: o que gravar em `config` e `segredoBusca`. */
export interface ConfigSelada {
  config: Record<string, unknown>;
  segredoBusca: string | null;
  /** Quantos segredos saíram do claro para a cifra nesta passada. */
  cifrados: number;
  /** Segredos que ficaram em claro por falta de chave. */
  emClaro: number;
}

/**
 * Cifra os segredos em claro de uma config e calcula o resumo de busca.
 *
 * `novos` = campos cujo valor em claro acabou de chegar (o lojista digitou):
 * sem chave, esses são recusados (`SemChaveDosSegredosException`) — guardar um
 * segredo novo em claro reabriria a brecha. Valor antigo em claro e sem chave
 * fica como está (a migração cifra quando a chave existir).
 */
export function selarConfig(
  conector: Conector,
  dono: DonoDoSegredo,
  config: Record<string, unknown>,
  buscaAtual: string | null,
  novos: ReadonlySet<string> = new Set(),
  chave: Buffer | null = chaveDosSegredos(),
): ConfigSelada {
  const out: Record<string, unknown> = { ...config };
  let segredoBusca = buscaAtual;
  let cifrados = 0;
  let emClaro = 0;
  for (const campo of conector.campos) {
    if (!campo.secret) continue;
    const valor = out[campo.key];
    if (typeof valor !== 'string' || !valor.trim()) continue;
    const contexto = contextoDoSegredo(dono, campo.key);

    if (ehCifrado(valor)) {
      // Já cifrado: só falta o resumo se a linha ainda não o tem.
      if (campo.busca && !segredoBusca && chave) {
        const claro = decifrar(valor, chave, contexto);
        if (claro !== null) segredoBusca = buscaDoSegredo(claro);
      }
      continue;
    }

    const claro = valor.trim();
    if (campo.busca) segredoBusca = buscaDoSegredo(claro);
    if (chave) {
      out[campo.key] = cifrar(claro, chave, contexto);
      cifrados += 1;
    } else if (novos.has(campo.key)) {
      logger.error(
        `Segredo novo de ${dono.tipo} recusado: ${ENV_CHAVE_DOS_SEGREDOS} ausente ou inválida.`,
      );
      throw new SemChaveDosSegredosException();
    } else {
      emClaro += 1;
    }
  }
  return { config: out, segredoBusca, cifrados, emClaro };
}
