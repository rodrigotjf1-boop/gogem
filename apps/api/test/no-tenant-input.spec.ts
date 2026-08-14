import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

/**
 * O `tenantId` (empresa) NUNCA pode vir do cliente — ele é injetado pelo
 * middleware do Prisma a partir do contexto (JWT/device token). Se um DTO ou
 * endpoint aceitasse `tenantId`/`empresaId` do body/query, um atacante poderia
 * agir "como outra empresa". Estes testes varrem o código-fonte para garantir
 * que essa porta nunca se abra (Fase 1 do plano de segurança).
 */

const SRC = join(process.cwd(), 'src');

function arquivos(filtro: (f: string) => boolean): string[] {
  return (readdirSync(SRC, { recursive: true, encoding: 'utf8' }) as string[])
    .filter(filtro)
    .map((f) => join(SRC, f));
}

describe('Nenhuma entrada aceita tenantId/empresaId do cliente', () => {
  it('nenhum *.dto.ts declara tenantId/empresaId como campo', () => {
    // Declaração de propriedade: "tenantId?: string", "empresaId: string" etc.
    const decl = /(^|[\s{,;])(tenantId|empresaId)\s*[?!]?\s*:/m;
    const violacoes = arquivos((f) => f.endsWith('.dto.ts'))
      .filter((f) => decl.test(readFileSync(f, 'utf8')))
      .map((f) => f.replace(SRC, ''));
    // Se falhar: remova o campo do DTO — o tenant vem do contexto, não do corpo.
    expect(violacoes).toEqual([]);
  });

  it('nenhum controller lê tenantId/empresaId de @Query/@Body/query/body', () => {
    const padroes = [
      /@Query\(\s*['"](tenantId|empresaId)['"]/,
      /@Param\(\s*['"](tenantId|empresaId)['"]/,
      /\b(?:body|query|req\.body|req\.query)\.(tenantId|empresaId)\b/,
    ];
    const violacoes: string[] = [];
    for (const f of arquivos(
      (x) => x.endsWith('.controller.ts') || x.endsWith('.ts'),
    )) {
      if (f.endsWith('.spec.ts')) continue;
      const src = readFileSync(f, 'utf8');
      if (padroes.some((p) => p.test(src))) violacoes.push(f.replace(SRC, ''));
    }
    expect(violacoes).toEqual([]);
  });
});
