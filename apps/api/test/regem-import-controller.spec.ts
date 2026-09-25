import { BadRequestException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { RegemImportController } from '../src/integracoes/regem/regem-import.controller';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import type { RegemImportService } from '../src/integracoes/regem/regem-import.service';

/**
 * ERR-012 — o botão "Importar do Regem" exigia as envs GLOBAIS: sem elas, recusava até a
 * empresa com integração própria; com elas, deixava importar quem não tinha integração
 * (e o resolvedor caía no Regem de outra empresa). Agora vale a integração DA EMPRESA.
 */
function montar(resolve: () => Promise<unknown>) {
  const service = { importar: vi.fn().mockResolvedValue({ ok: true }) };
  const regem = { resolve: vi.fn(resolve) };
  const ctrl = new RegemImportController(
    service as unknown as RegemImportService,
    regem as unknown as RegemConfigResolver,
  );
  return { ctrl, service };
}

describe('POST /import/regem — exige a integração da empresa', () => {
  it('empresa com integração: importa (sem precisar de env nenhuma)', async () => {
    const { ctrl, service } = montar(() =>
      Promise.resolve({ base: 'https://regem', token: 't' }),
    );
    await ctrl.importar();
    expect(service.importar).toHaveBeenCalled();
  });

  it('empresa sem integração: 400 com o motivo, e nada importado', async () => {
    const { ctrl, service } = montar(() =>
      Promise.reject(
        new Error('Integração Regem não configurada para esta loja'),
      ),
    );
    const err = await ctrl.importar().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(BadRequestException);
    expect(String((err as Error).message)).toContain('não configurada');
    expect(service.importar).not.toHaveBeenCalled();
  });
});
