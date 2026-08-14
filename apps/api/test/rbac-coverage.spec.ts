import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Guarda de regressão de RBAC (Fase 2 do plano de segurança).
 *
 * Toda MUTAÇÃO (@Post/@Patch/@Put/@Delete) atrás do JwtAuthGuard tem que exigir
 * um papel mínimo (@Roles) — no nível da classe ou do método. Sem isso, qualquer
 * usuário autenticado (até `execucao`) poderia mutar. Endpoints de device/webhook
 * (DeviceTokenGuard/Org/OAuth) e os públicos de auth (login/register) não entram
 * nessa regra — não são "mutação JWT sem papel".
 */

const SRC = join(process.cwd(), 'src');
const MUT = /@(Post|Patch|Put|Delete)\(/;

function controllers(): string[] {
  return (readdirSync(SRC, { recursive: true, encoding: 'utf8' }) as string[])
    .filter((f) => f.endsWith('.controller.ts'))
    .map((f) => join(SRC, f));
}

/** Bloco de decorators de um método a partir da linha do verbo HTTP. */
function blocoDoMetodo(linhas: string[], i: number): string {
  const out = [linhas[i]];
  for (let j = i + 1; j < linhas.length; j++) {
    const t = linhas[j].trim();
    if (t === '' || t.startsWith('@')) {
      out.push(linhas[j]);
      continue;
    }
    break; // chegou na assinatura do método
  }
  return out.join('\n');
}

describe('Cobertura de RBAC — mutações exigem papel', () => {
  it('nenhuma mutação atrás do JwtAuthGuard fica sem @Roles', () => {
    const violacoes: string[] = [];
    let avaliadas = 0; // mutações JWT verificadas (evita teste vazio/vacuoso)
    for (const file of controllers()) {
      const src = readFileSync(file, 'utf8');
      const idxClasse = src.indexOf('export class');
      const cabecalho = idxClasse >= 0 ? src.slice(0, idxClasse) : '';
      const classeTemJwt = /@UseGuards\([^)]*JwtAuthGuard/.test(cabecalho);
      const classeTemRoles = /@Roles\(/.test(cabecalho);

      const linhas = src.split('\n');
      for (let i = 0; i < linhas.length; i++) {
        if (!MUT.test(linhas[i])) continue;
        const bloco = blocoDoMetodo(linhas, i);
        const metodoTemJwt = /@UseGuards\([^)]*JwtAuthGuard/.test(bloco);
        const atrasDeJwt = classeTemJwt || metodoTemJwt;
        if (!atrasDeJwt) continue; // device/webhook/público — outra regra

        avaliadas += 1;
        const temRoles = classeTemRoles || /@Roles\(/.test(bloco);
        if (!temRoles) {
          violacoes.push(`${file.replace(SRC, '')}:${i + 1}`);
        }
      }
    }
    // Se falhar: adicione @Roles('gerente' | 'presidente' | ...) na mutação
    // (ou na classe). Nunca deixe uma mutação JWT sem papel mínimo.
    expect(violacoes).toEqual([]);
    // Sanidade: o scan realmente cobriu as mutações protegidas (não é vacuoso).
    expect(avaliadas).toBeGreaterThanOrEqual(20);
  });
});
