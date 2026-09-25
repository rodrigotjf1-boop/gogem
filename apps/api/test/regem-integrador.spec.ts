import { afterEach, describe, expect, it, vi } from 'vitest';
import { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import { RegemPauseClient } from '../src/integracoes/regem/regem-pause.client';
import type { RegemConfigResolver } from '../src/integracoes/regem/regem-config.resolver';

/**
 * ERR-027 — o Regem só sabe qual dos equipamentos `servidor_local` é a credencial do GoGeM
 * porque o GoGeM se identifica (`X-Integrador: gogem`) — e é com esse token que ele avisa um
 * cancelamento para o GoGeM estornar. Quem marca na prática é a chamada do CATÁLOGO: o sync
 * automático (a cada 5 min) e o "Testar conexão" do painel. Sem o cabeçalho nela, o aviso volta a
 * sair com o token de outro equipamento (401) e o cartão/PIX do cliente não é devolvido.
 */
const resolver = {
  resolve: vi
    .fn()
    .mockResolvedValue({ base: 'https://regem/api/v1', token: 't' }),
} as unknown as RegemConfigResolver;

function responde(status: number, body: unknown) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue(
      new Response(JSON.stringify(body), {
        status,
        headers: { 'content-type': 'application/json' },
      }),
    ),
  );
}

function cabecalhosDaChamada(): Record<string, string> {
  const init = vi.mocked(fetch).mock.calls[0][1] as RequestInit;
  return init.headers as Record<string, string>;
}

describe('o GoGeM se identifica ao Regem (ERR-027)', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('catálogo do sync automático: X-Integrador: gogem ao lado do token', async () => {
    responde(200, { produtos: [] });
    await new RegemCatalogClient(resolver).fetchCatalogo();
    expect(cabecalhosDaChamada()).toMatchObject({
      'X-Sync-Token': 't',
      'X-Integrador': 'gogem',
    });
  });

  it('"Testar conexão" (config ainda não ativada): também se identifica', async () => {
    responde(200, { produtos: [] });
    await new RegemCatalogClient(resolver).fetchCatalogoWith({
      base: 'https://regem/api/v1',
      token: 'novo',
    });
    expect(cabecalhosDaChamada()).toMatchObject({
      'X-Sync-Token': 'novo',
      'X-Integrador': 'gogem',
    });
  });

  it('pausa de item: também se identifica', async () => {
    responde(200, {});
    expect(await new RegemPauseClient(resolver).pausar('A1', true)).toBe(true);
    expect(cabecalhosDaChamada()).toMatchObject({
      'X-Sync-Token': 't',
      'X-Integrador': 'gogem',
    });
  });
});
