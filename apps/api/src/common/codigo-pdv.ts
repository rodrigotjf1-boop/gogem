/**
 * Código PDV do Regem no de-para (`externalRefs`, Json) — a chave com que a venda chega ao
 * Regem (CLAUDE.md §4). `null` quando não há vínculo (ou o código está vazio).
 */
export function codigoPdvRegem(externalRefs: unknown): string | null {
  if (!Array.isArray(externalRefs)) return null;
  for (const r of externalRefs) {
    if (r && typeof r === 'object' && !Array.isArray(r)) {
      const ref = r as Record<string, unknown>;
      if (ref.sistema === 'regem' && typeof ref.codigo_pdv === 'string') {
        const codigo = ref.codigo_pdv.trim();
        if (codigo) return codigo;
      }
    }
  }
  return null;
}
