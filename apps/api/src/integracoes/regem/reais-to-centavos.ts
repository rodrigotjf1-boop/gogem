/**
 * Converte um valor em reais (contrato do Regem: DECIMAL numeric serializado
 * como string, ex. "29.90") para centavos inteiros.
 *
 * Regra: `Math.round(parseFloat(x) * 100)` — inteiro-seguro para o domínio de
 * preços (2 casas). Documentação do arredondamento (half-away-from-zero do
 * `Math.round`, sujeito à representação binária do double):
 *   "29.90"  → 2990
 *   "0.1"    → 10
 *   "19.99"  → 1999
 *   "12.345" → 1235   (3ª casa arredonda pra cima)
 *   "0.005"  → 1      (arredonda pra cima)
 * Valores nulos/vazios/não-numéricos viram 0 (produto/opção sem preço).
 */
export function reaisToCentavos(
  valor: string | number | null | undefined,
): number {
  if (valor === null || valor === undefined || valor === '') return 0;
  const n = typeof valor === 'number' ? valor : parseFloat(valor);
  if (Number.isNaN(n)) return 0;
  return Math.round(n * 100);
}
