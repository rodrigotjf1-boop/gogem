import { BadRequestException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { RegemImportController } from '../src/integracoes/regem/regem-import.controller';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';
import type { RegemImportService } from '../src/integracoes/regem/regem-import.service';
import { SegredoIlegivelException } from '../src/integracao/segredos';

/**
 * ERR-012 — o botão "Importar do Regem" exigia as envs GLOBAIS: sem elas, recusava até a
 * empresa com integração própria; com elas, deixava importar quem não tinha integração
 * (e o resolvedor caía no Regem de outra empresa). Agora vale a integração DA EMPRESA.
 *
 * ERR-051 — o Catálogo do painel pede as novidades sempre que abre; na empresa sem Regem a
 * rota devolvia 500 e deixava ERROR com pilha no log a cada abertura. Agora: 400 com o motivo.
 */
function montar(resolve: () => Promise<unknown>) {
  const service = {
    importar: vi.fn().mockResolvedValue({ ok: true }),
    novidades: vi.fn().mockResolvedValue({ novos: [], orfaos: [] }),
  };
  const regem = { resolve: vi.fn(resolve) };
  const ctrl = new RegemImportController(
    service as unknown as RegemImportService,
    regem as unknown as RegemConfigResolver,
  );
  return { ctrl, service };
}

const semIntegracao = () =>
  Promise.reject(new Error('Integração Regem não configurada para esta loja'));

describe('POST /import/regem — exige a integração da empresa', () => {
  it('empresa com integração: importa (sem precisar de env nenhuma)', async () => {
    const { ctrl, service } = montar(() =>
      Promise.resolve({ base: 'https://regem', token: 't' }),
    );
    await ctrl.importar();
    expect(service.importar).toHaveBeenCalled();
  });

  it('empresa sem integração: 400 com o motivo, e nada importado', async () => {
    const { ctrl, service } = montar(semIntegracao);
    const err = await ctrl.importar().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(BadRequestException);
    expect(String((err as Error).message)).toContain('não configurada');
    expect(service.importar).not.toHaveBeenCalled();
  });

  it('credencial guardada que não abre: o 503 passa como veio, não vira 400', async () => {
    const { ctrl, service } = montar(() =>
      Promise.reject(new SegredoIlegivelException()),
    );
    const err = await ctrl.importar().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(SegredoIlegivelException);
    expect((err as SegredoIlegivelException).getStatus()).toBe(503);
    expect(service.importar).not.toHaveBeenCalled();
  });
});

describe('GET /import/regem/novidades — empresa sem Regem é resposta, não erro do servidor', () => {
  it('empresa com integração: devolve as novidades do serviço', async () => {
    const { ctrl, service } = montar(() =>
      Promise.resolve({ base: 'https://regem', token: 't' }),
    );
    await expect(ctrl.novidades()).resolves.toEqual({ novos: [], orfaos: [] });
    expect(service.novidades).toHaveBeenCalled();
  });

  it('empresa sem integração: 400 com o motivo, sem chamar o Regem', async () => {
    const { ctrl, service } = montar(semIntegracao);
    const err = await ctrl.novidades().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(BadRequestException);
    expect(String((err as Error).message)).toContain('não configurada');
    expect(service.novidades).not.toHaveBeenCalled();
  });

  it('credencial guardada que não abre: o 503 passa como veio', async () => {
    const { ctrl, service } = montar(() =>
      Promise.reject(new SegredoIlegivelException()),
    );
    const err = await ctrl.novidades().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(SegredoIlegivelException);
    expect(service.novidades).not.toHaveBeenCalled();
  });
});
