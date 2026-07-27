/**
 * Dinheiro em centavos (inteiro) — a fonte da verdade é sempre centavos
 * (CLAUDE.md; nunca float). Estes helpers só convertem para exibição/entrada.
 */

/** Formata centavos como moeda pt-BR. Ex.: 2590 → "R$ 25,90". */
export function formatarBRL(centavos: number): string {
  return (centavos / 100).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  });
}

/**
 * Converte uma entrada em reais (string do usuário) para centavos inteiros.
 * Aceita "25,90", "25.90", "25" e milhar "1.234,50". Retorna `null` se a
 * string não for um número válido — o chamador trata como erro de validação.
 */
export function reaisParaCentavos(entrada: string): number | null {
  const limpo = entrada.trim();
  if (limpo === '') return null;

  // Remove separador de milhar e normaliza a vírgula decimal para ponto.
  // Heurística pt-BR: a vírgula (se houver) é o separador decimal.
  let normalizado: string;
  if (limpo.includes(',')) {
    normalizado = limpo.replace(/\./g, '').replace(',', '.');
  } else {
    normalizado = limpo;
  }

  const valor = Number(normalizado);
  if (!Number.isFinite(valor) || valor < 0) return null;

  // Arredonda para o centavo mais próximo evitando erro de ponto flutuante.
  return Math.round(valor * 100);
}

/** Centavos → string editável em reais (ponto vira vírgula). Ex.: 2590 → "25,90". */
export function centavosParaReais(centavos: number): string {
  return (centavos / 100).toFixed(2).replace('.', ',');
}
