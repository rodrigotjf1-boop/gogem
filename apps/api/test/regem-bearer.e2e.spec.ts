import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  RegemCredencialRecusadaError,
  RegemLimiteError,
  esquecerEsperasDoRegem,
} from '../src/integracoes/regem/chamada-regem';
import { RegemCatalogClient } from '../src/integracoes/regem/regem-catalog.client';
import { RegemPauseClient } from '../src/integracoes/regem/regem-pause.client';
import { RegemSalesClient } from '../src/integracoes/regem/regem-sales.client';
import type {
  RegemConfig,
  RegemConfigResolver,
} from '../src/integracoes/regem/regem-config.resolver';

/**
 * Prova contra o Regem DE VERDADE (opt-in): o código do Regem rodando local, em modo nuvem,
 * com um banco descartável e uma loja de teste (tokens de baixa entropia que só existem lá):
 *   REGEM_E2E_URL=http://localhost:3401/api/v1 npx vitest run test/regem-bearer.e2e.spec.ts
 * Tokens da semente: e = os 3 escopos do totem; f = só o catálogo; g = revogado;
 * h = só o catálogo, para provocar o 429 (60 chamadas por minuto por token).
 * Rodar UMA vez por minuto: o Regem também limita 120 chamadas por minuto por IP.
 */
const BASE = process.env.REGEM_E2E_URL;
const token = (letra: string) => `rgm_it_${letra.repeat(43)}`;

const cfg = (tokenIntegracao: string | null, id: string): RegemConfig => ({
  base: BASE ?? '',
  token: 'token-antigo-e2e',
  tokenIntegracao,
  integracaoId: id,
  credencialRecusada: null,
});

function resolverCom(c: RegemConfig) {
  return {
    resolve: vi.fn().mockResolvedValue(c),
    marcarCredencialRecusada: vi.fn().mockResolvedValue(undefined),
  };
}

const venda = (chave: string) => ({
  idempotencyKey: chave,
  itens: [{ codigoPdv: 'E2E-1', quantidade: 1 }],
  pagamentos: [{ forma: 'dinheiro', valor: 10 }],
});

describe.skipIf(!BASE)(
  'Regem de verdade — Bearer rgm_it_ nas 5 rotas do totem',
  () => {
    beforeEach(() => esquecerEsperasDoRegem());

    it('catálogo com o token novo traz o produto da loja de teste', async () => {
      const r = resolverCom(cfg(token('e'), 'e2e-e'));
      const c = await new RegemCatalogClient(
        r as unknown as RegemConfigResolver,
      ).fetchCatalogo();
      expect(c.produtos.map((p) => p.codigo)).toContain('E2E-1');
    });

    it('pausa e despausa com o token novo', async () => {
      const r = resolverCom(cfg(token('e'), 'e2e-e'));
      const pausa = new RegemPauseClient(r as unknown as RegemConfigResolver);
      expect(await pausa.pausar('E2E-1', true)).toBe(true);
      expect(await pausa.pausar('E2E-1', false)).toBe(true);
    });

    it('venda, pedido em dinheiro e falha passam da credencial', async () => {
      const r = resolverCom(cfg(token('e'), 'e2e-e'));
      const vendas = new RegemSalesClient(r as unknown as RegemConfigResolver);
      const sufixo = Date.now().toString(36);

      const resultado = await vendas
        .lancarVendaExterna(venda(`e2e-venda-${sufixo}`) as never)
        .then((v) => ({ ok: true as const, v }))
        .catch((e: Error) => ({ ok: false as const, e }));
      // Passou da credencial: ou vendeu, ou o Regem recusou pela REGRA da venda — nunca 401/403.
      if (!resultado.ok) {
        expect(resultado.e).not.toBeInstanceOf(RegemCredencialRecusadaError);
        expect(resultado.e).not.toBeInstanceOf(RegemLimiteError);
      }
      console.log(
        'venda:',
        resultado.ok
          ? `vendida, comanda ${resultado.v.comandaId}`
          : resultado.e.message,
      );

      const dinheiro = await vendas
        .lancarTotemDinheiro({
          idempotencyKey: `e2e-dinheiro-${sufixo}`,
          itens: [{ codigoPdv: 'E2E-1', quantidade: 1 }] as never,
        })
        .then((v) => ({ ok: true as const, v }))
        .catch((e: Error) => ({ ok: false as const, e }));
      if (!dinheiro.ok) {
        expect(dinheiro.e).not.toBeInstanceOf(RegemCredencialRecusadaError);
      }
      console.log(
        'dinheiro:',
        dinheiro.ok
          ? `senha ${dinheiro.v.senha}, comanda ${dinheiro.v.comandaId}`
          : dinheiro.e.message,
      );

      await expect(
        vendas.relatarFalha({
          idempotencyKey: `e2e-falha-${sufixo}`,
          itens: [{ codigoPdv: 'E2E-1', quantidade: 1 }] as never,
          formaTentada: 'pix',
          totalCentavos: 1000,
          motivo: 'teste e2e',
        }),
      ).resolves.toBeUndefined();
      expect(r.marcarCredencialRecusada).not.toHaveBeenCalled();
    });

    it('token revogado → 401, recusa marcada e sem voltar ao token antigo', async () => {
      const c = cfg(token('g'), 'e2e-g');
      const r = resolverCom(c);
      const erro = await new RegemCatalogClient(
        r as unknown as RegemConfigResolver,
      )
        .fetchCatalogo()
        .catch((e) => e);
      expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
      expect(erro.status).toBe(401);
      expect(r.marcarCredencialRecusada).toHaveBeenCalledWith(
        c,
        401,
        expect.stringContaining('revogado'),
      );
    });

    it('token sem o escopo de venda → 403 na venda; o catálogo, que ele tem, passa', async () => {
      const r = resolverCom(cfg(token('f'), 'e2e-f'));
      const catalogo = await new RegemCatalogClient(
        r as unknown as RegemConfigResolver,
      ).fetchCatalogo();
      expect(catalogo.produtos.length).toBeGreaterThan(0);

      const erro = await new RegemSalesClient(
        r as unknown as RegemConfigResolver,
      )
        .lancarVendaExterna(venda(`e2e-sem-escopo-${Date.now()}`) as never)
        .catch((e) => e);
      expect(erro).toBeInstanceOf(RegemCredencialRecusadaError);
      expect(erro.status).toBe(403);
      expect(erro.message).toContain('totem.vendas.lancar');
    });

    it('o caminho antigo (sem token novo) segue funcionando', async () => {
      const r = resolverCom(cfg(null, 'e2e-antigo'));
      const c = await new RegemCatalogClient(
        r as unknown as RegemConfigResolver,
      ).fetchCatalogo();
      expect(c.produtos.map((p) => p.codigo)).toContain('E2E-1');
    });

    it('passou de 60 chamadas no minuto → 429 com Retry-After, e o GoGeM espera', async () => {
      const r = resolverCom(cfg(token('h'), 'e2e-h'));
      const catalogo = new RegemCatalogClient(
        r as unknown as RegemConfigResolver,
      );
      let limite: RegemLimiteError | null = null;
      let chamadas = 0;
      for (let i = 0; i < 70 && !limite; i++) {
        chamadas += 1;
        await catalogo.fetchCatalogo().catch((e) => {
          if (e instanceof RegemLimiteError) limite = e;
          else throw e;
        });
      }
      expect(limite).toBeInstanceOf(RegemLimiteError);
      expect(chamadas).toBe(61);
      const espera = (limite as unknown as RegemLimiteError).esperaSeg;
      expect(espera).toBeGreaterThanOrEqual(1);
      expect(espera).toBeLessThanOrEqual(60);
      // Durante a espera, o GoGeM nem chama o Regem.
      const fetchReal = globalThis.fetch;
      const espiao = vi.fn(fetchReal);
      vi.stubGlobal('fetch', espiao);
      await expect(catalogo.fetchCatalogo()).rejects.toBeInstanceOf(
        RegemLimiteError,
      );
      expect(espiao).not.toHaveBeenCalled();
      vi.unstubAllGlobals();
    });
  },
);
