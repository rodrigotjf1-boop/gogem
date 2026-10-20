import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
  BadRequestException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  JANELA_DO_ANTERIOR_MS,
  REGISTRAR_DE_NOVO_MS,
  URL_PUBLICA_PADRAO,
  assinarAviso,
  chaveDoSegredo,
  conferirAvisoAssinado,
  enderecoDosAvisos,
  lerEstadoDosAvisos,
  novoSegredoDosAvisos,
} from '../src/integracoes/regem/avisos-regem';
import { RegemAvisosService } from '../src/integracoes/regem/regem-avisos.service';
import { RegemInboundService } from '../src/integracoes/regem/regem-inbound.service';
import { esquecerEsperasDoRegem } from '../src/integracoes/regem/chamada-regem';
import { cifrar, decifrar } from '../src/common/cifra';
import { buscaDoSegredo, contextoDoSegredo } from '../src/integracao/segredos';
import type {
  RegemConfig,
  RegemConfigResolver,
} from '../src/integracoes/regem/regem-config.resolver';
import type { PrismaService } from '../src/prisma/prisma.service';

/**
 * Avisos assinados do Regem ao GoGeM — contrato 1 (`AVISOS-ASSINADOS.md` do Regem, §2 a §6).
 */

// O vetor do §3 do contrato (o segredo de exemplo do próprio Standard Webhooks).
const VETOR = {
  segredo: 'whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw',
  id: 'aviso_5d9f1c2e-7b3a-4c1d-9e8f-0a1b2c3d4e5f',
  timestamp: '1792444445',
  corpo:
    '{"tipo":"pedido.cancelado","contrato":1,"loja_id":"3f2a6b1c-0d4e-4f5a-8b9c-1d2e3f4a5b6c","cancelado_em":"2026-10-19T21:14:05.000Z","pedido":{"idempotencyKey":"totem-7f3e9a","regemComandaId":"9b8c7d6e-5f4a-4b3c-2d1e-0f9a8b7c6d5e","motivo":"Cliente desistiu"}}',
  assinatura: 'v1,HCkTVm4dLgQ3u7I1gRWpJRTcGU2jcgTizQ7kZe1t/7U=',
};
const NO_VETOR = new Date(Number(VETOR.timestamp) * 1000);

// Chave dos segredos e token de baixa entropia: só valem aqui.
const CHAVE = Buffer.alloc(32, 7);
const TOKEN = `rgm_it_${'c'.repeat(43)}`;
const DONO = { tenantId: 't1', unidadeId: null, tipo: 'regem' };
const CONTEXTO = contextoDoSegredo(DONO, 'avisos');

describe('assinatura — o vetor do §3 tem de bater', () => {
  it('assina o vetor igual ao contrato', () => {
    const chave = chaveDoSegredo(VETOR.segredo)!;
    expect(assinarAviso(chave, VETOR.id, VETOR.timestamp, VETOR.corpo)).toBe(
      VETOR.assinatura,
    );
  });

  it('confere o vetor', () => {
    expect(
      conferirAvisoAssinado({
        id: VETOR.id,
        timestamp: VETOR.timestamp,
        assinatura: VETOR.assinatura,
        corpo: VETOR.corpo,
        chaves: [chaveDoSegredo(VETOR.segredo)!],
        agora: NO_VETOR,
      }),
    ).toBe('ok');
  });

  it('relógio a mais de 5 min, para mais ou para menos → fora do prazo', () => {
    const base = {
      id: VETOR.id,
      timestamp: VETOR.timestamp,
      assinatura: VETOR.assinatura,
      corpo: VETOR.corpo,
      chaves: [chaveDoSegredo(VETOR.segredo)!],
    };
    expect(
      conferirAvisoAssinado({
        ...base,
        agora: new Date(NO_VETOR.getTime() + 300_000),
      }),
    ).toBe('ok');
    expect(
      conferirAvisoAssinado({
        ...base,
        agora: new Date(NO_VETOR.getTime() + 301_000),
      }),
    ).toBe('fora_do_prazo');
    expect(
      conferirAvisoAssinado({
        ...base,
        agora: new Date(NO_VETOR.getTime() - 301_000),
      }),
    ).toBe('fora_do_prazo');
  });

  it('corpo mexido (até um espaço), outro segredo ou cabeçalho faltando → recusa', () => {
    const chave = chaveDoSegredo(VETOR.segredo)!;
    const base = {
      id: VETOR.id,
      timestamp: VETOR.timestamp,
      assinatura: VETOR.assinatura,
      corpo: VETOR.corpo,
      chaves: [chave],
      agora: NO_VETOR,
    };
    expect(
      conferirAvisoAssinado({
        ...base,
        corpo: VETOR.corpo.replace(':1,', ': 1,'),
      }),
    ).toBe('assinatura');
    expect(
      conferirAvisoAssinado({ ...base, chaves: [Buffer.alloc(32, 1)] }),
    ).toBe('assinatura');
    expect(conferirAvisoAssinado({ ...base, id: undefined })).toBe(
      'sem_cabecalho',
    );
    expect(conferirAvisoAssinado({ ...base, timestamp: 'ontem' })).toBe(
      'sem_cabecalho',
    );
    expect(conferirAvisoAssinado({ ...base, assinatura: '' })).toBe(
      'sem_cabecalho',
    );
  });

  it('várias assinaturas separadas por espaço: vale se uma bater; vale a chave anterior', () => {
    const chave = chaveDoSegredo(VETOR.segredo)!;
    const outra = Buffer.alloc(32, 9);
    const varias = `v1,AAAA ${VETOR.assinatura} v2,ignorada`;
    expect(
      conferirAvisoAssinado({
        id: VETOR.id,
        timestamp: VETOR.timestamp,
        assinatura: varias,
        corpo: VETOR.corpo,
        chaves: [outra, chave],
        agora: NO_VETOR,
      }),
    ).toBe('ok');
  });

  it('segredo: whsec_ + 32 bytes; formato errado não vira chave', () => {
    const s = novoSegredoDosAvisos();
    expect(s.startsWith('whsec_')).toBe(true);
    expect(chaveDoSegredo(s)?.length).toBe(32);
    expect(chaveDoSegredo('abc')).toBeNull();
    expect(
      chaveDoSegredo(`whsec_${Buffer.alloc(8, 1).toString('base64')}`),
    ).toBeNull();
    expect(chaveDoSegredo('whsec_não-é-base64!')).toBeNull();
  });

  it('o endereço registrado começa pelo que o Regem aceita', () => {
    expect(enderecoDosAvisos('integ-1', URL_PUBLICA_PADRAO)).toBe(
      'https://api.gogem.com.br/api/v1/sync/regem/avisos/integ-1',
    );
  });
});

// ── O serviço: conferir, registrar, desligar ────────────────────────────────

const SEGREDO_ATUAL = `whsec_${Buffer.alloc(32, 5).toString('base64')}`;
const SEGREDO_VELHO = `whsec_${Buffer.alloc(32, 6).toString('base64')}`;

function estadoLigado(extra: Record<string, unknown> = {}) {
  return {
    segredo: cifrar(SEGREDO_ATUAL, CHAVE, CONTEXTO),
    anterior: null,
    trocadoEm: null,
    resumoDoToken: buscaDoSegredo(TOKEN),
    registradoEm: '2026-10-20T03:00:00.000Z',
    tentadoEm: '2026-10-20T03:00:00.000Z',
    erro: null,
    ...extra,
  };
}

function prismaCom(linha: Record<string, unknown> | null) {
  const atual = linha ? { ...linha } : null;
  const ordem: string[] = [];
  const prisma = {
    integracao: {
      findFirst: vi
        .fn()
        .mockImplementation(async () => (atual ? { ...atual } : null)),
      updateMany: vi.fn().mockImplementation(async ({ data }: any) => {
        ordem.push('gravou-antes');
        if (atual) Object.assign(atual, data);
        return { count: 1 };
      }),
      update: vi.fn().mockImplementation(async ({ data }: any) => {
        ordem.push('gravou-depois');
        if (atual) Object.assign(atual, data);
        return atual;
      }),
    },
  };
  return { prisma, atual: () => atual, ordem };
}

const cfg = (extra: Partial<RegemConfig> = {}): RegemConfig => ({
  base: 'https://regem/api/v1',
  token: 'token-antigo',
  tokenIntegracao: TOKEN,
  integracaoId: 'integ-1',
  credencialRecusada: null,
  ...extra,
});

function respostaDoRegem(status: number, body: unknown = {}, ordem?: string[]) {
  const f = vi.fn().mockImplementation(async () => {
    ordem?.push('regem');
    return new Response(status === 204 ? null : JSON.stringify(body), {
      status,
      headers: { 'content-type': 'application/json' },
    });
  });
  vi.stubGlobal('fetch', f);
  return f;
}

const resolverFalso = () => ({ marcarCredencialRecusada: vi.fn() });

beforeEach(() => {
  process.env.GOGEM_CHAVE_DOS_SEGREDOS = CHAVE.toString('base64');
  esquecerEsperasDoRegem();
});
afterEach(() => {
  delete process.env.GOGEM_CHAVE_DOS_SEGREDOS;
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('conferir o aviso que chega (§3, nesta ordem)', () => {
  const linha = (extra: Record<string, unknown> = {}) => ({
    id: 'integ-1',
    ...DONO,
    ativo: true,
    avisos: estadoLigado(),
    ...extra,
  });
  const servico = (l: Record<string, unknown> | null) =>
    new RegemAvisosService(
      prismaCom(l).prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    );
  const cabecalhos = (
    corpo: string,
    chave: Buffer,
    ts: number,
    id = 'aviso_1',
  ) => ({
    'webhook-id': id,
    'webhook-timestamp': String(ts),
    'webhook-signature': assinarAviso(chave, id, ts, corpo),
  });
  const agora = new Date('2026-10-20T03:10:00.000Z');
  const ts = Math.floor(agora.getTime() / 1000);
  const corpo = '{"tipo":"catalogo.publicar","contrato":1,"loja_id":"x"}';

  it('assinado com o segredo atual → passa, com a empresa e o corpo', async () => {
    const r = await servico(linha()).conferir(
      'integ-1',
      cabecalhos(corpo, chaveDoSegredo(SEGREDO_ATUAL)!, ts),
      corpo,
      agora,
    );
    expect(r).toEqual({ tenantId: 't1', corpo: JSON.parse(corpo) });
  });

  it('integração desconhecida, desligada ou sem avisos → 401', async () => {
    const h = cabecalhos(corpo, chaveDoSegredo(SEGREDO_ATUAL)!, ts);
    await expect(
      servico(null).conferir('integ-1', h, corpo, agora),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(
      servico(linha({ ativo: false })).conferir('integ-1', h, corpo, agora),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(
      servico(linha({ avisos: null })).conferir('integ-1', h, corpo, agora),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('endereço fora do formato nem vai ao banco → 401', async () => {
    const { prisma } = prismaCom(linha());
    const s = new RegemAvisosService(
      prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    );
    await expect(
      s.conferir('../../x', {}, corpo, agora),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.integracao.findFirst).not.toHaveBeenCalled();
  });

  it('assinatura de outro segredo ou relógio fora → 401', async () => {
    await expect(
      servico(linha()).conferir(
        'integ-1',
        cabecalhos(corpo, Buffer.alloc(32, 1), ts),
        corpo,
        agora,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(
      servico(linha()).conferir(
        'integ-1',
        cabecalhos(corpo, chaveDoSegredo(SEGREDO_ATUAL)!, ts - 600),
        corpo,
        agora,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('o segredo anterior vale por 10 min depois da troca, e não mais', async () => {
    const trocado = new Date(agora.getTime() - 5 * 60_000).toISOString();
    const comAnterior = linha({
      avisos: estadoLigado({
        anterior: cifrar(SEGREDO_VELHO, CHAVE, CONTEXTO),
        trocadoEm: trocado,
      }),
    });
    const hVelho = cabecalhos(corpo, chaveDoSegredo(SEGREDO_VELHO)!, ts);
    await expect(
      servico(comAnterior).conferir('integ-1', hVelho, corpo, agora),
    ).resolves.toMatchObject({
      tenantId: 't1',
    });
    const muitoDepois = new Date(
      Date.parse(trocado) + JANELA_DO_ANTERIOR_MS + 60_000,
    );
    const tsDepois = Math.floor(muitoDepois.getTime() / 1000);
    await expect(
      servico(comAnterior).conferir(
        'integ-1',
        cabecalhos(corpo, chaveDoSegredo(SEGREDO_VELHO)!, tsDepois),
        corpo,
        muitoDepois,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('contrato diferente de 1 → 422 contrato-nao-suportado; corpo assinado que não é JSON → 400', async () => {
    const dois = '{"tipo":"catalogo.publicar","contrato":2}';
    const erro = await servico(linha())
      .conferir(
        'integ-1',
        cabecalhos(dois, chaveDoSegredo(SEGREDO_ATUAL)!, ts),
        dois,
        agora,
      )
      .catch((e) => e);
    expect(erro).toBeInstanceOf(UnprocessableEntityException);
    expect(erro.getResponse()).toMatchObject({
      code: 'contrato-nao-suportado',
    });

    const torto = 'isto não é json';
    await expect(
      servico(linha()).conferir(
        'integ-1',
        cabecalhos(torto, chaveDoSegredo(SEGREDO_ATUAL)!, ts),
        torto,
        agora,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('ligar os avisos no Regem (§2)', () => {
  const linhaSemAvisos = () => ({ id: 'integ-1', ...DONO, avisos: null });

  it('primeira vez: guarda o segredo ANTES do PUT, manda o endereço e o whsec_, e marca ligado', async () => {
    const { prisma, atual, ordem } = prismaCom(linhaSemAvisos());
    const f = respostaDoRegem(200, { url: 'x', registrado_em: 'y' }, ordem);
    const s = new RegemAvisosService(
      prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    );

    const situacao = await s.garantirRegistro(cfg(), { forcar: true });

    expect(ordem).toEqual(['gravou-antes', 'regem', 'gravou-depois']);
    const [url, init] = f.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://regem/api/v1/integracao/webhook');
    expect(init.method).toBe('PUT');
    expect((init.headers as Record<string, string>).Authorization).toBe(
      `Bearer ${TOKEN}`,
    );
    const enviado = JSON.parse(String(init.body));
    expect(enviado.url).toBe(
      'https://api.gogem.com.br/api/v1/sync/regem/avisos/integ-1',
    );
    expect(chaveDoSegredo(enviado.segredo)?.length).toBe(32);

    // O segredo guardado é o mesmo que foi ao Regem — e guardado cifrado.
    const estado = lerEstadoDosAvisos(atual()!.avisos)!;
    expect(estado.segredo).toMatch(/^v1\./);
    expect(decifrar(estado.segredo, CHAVE, CONTEXTO)).toBe(enviado.segredo);
    expect(estado.resumoDoToken).toBe(buscaDoSegredo(TOKEN));
    expect(estado.registradoEm).toBeTruthy();
    expect(situacao.ligados).toBe(true);
    // Na CAS da gravação "antes", a coluna vazia é comparada como nula.
    expect(prisma.integracao.updateMany.mock.calls[0][0].where.avisos).toEqual({
      equals: Prisma.AnyNull,
    });
  });

  it('o Regem recusa o registro (403/422) → avisos não ligados, e o token NÃO é marcado como recusado', async () => {
    const { prisma, atual } = prismaCom(linhaSemAvisos());
    respostaDoRegem(403, {
      type: 'x/escopo-insuficiente',
      detail: 'sem aviso para este cliente',
    });
    const resolver = resolverFalso();
    const situacao = await new RegemAvisosService(
      prisma as unknown as PrismaService,
      resolver as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { forcar: true });
    expect(situacao.ligados).toBe(false);
    expect(situacao.detalhe).toContain('403');
    expect(lerEstadoDosAvisos(atual()!.avisos)!.erro).toContain(
      'sem aviso para este cliente',
    );
    expect(resolver.marcarCredencialRecusada).not.toHaveBeenCalled();
  });

  it('a rotina diária só religa o que já está ligado com o MESMO token, e com o MESMO segredo', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    const registradoEm = '2026-10-20T03:00:00.000Z';
    vi.setSystemTime(new Date(Date.parse(registradoEm) + 60 * 60_000)); // 1 h depois

    // Nunca ligado → a rotina não liga.
    let p = prismaCom(linhaSemAvisos());
    let f = respostaDoRegem(200);
    await new RegemAvisosService(
      p.prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { soReativar: true });
    expect(f).not.toHaveBeenCalled();

    // Ligado há 1 h → nada a fazer.
    p = prismaCom({
      id: 'integ-1',
      ...DONO,
      avisos: estadoLigado({ registradoEm }),
    });
    f = respostaDoRegem(200);
    await new RegemAvisosService(
      p.prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { soReativar: true });
    expect(f).not.toHaveBeenCalled();

    // Ligado há mais de 20 h → religa, com o mesmo segredo (não troca).
    vi.setSystemTime(
      new Date(Date.parse(registradoEm) + REGISTRAR_DE_NOVO_MS + 60_000),
    );
    p = prismaCom({
      id: 'integ-1',
      ...DONO,
      avisos: estadoLigado({ registradoEm, tentadoEm: registradoEm }),
    });
    f = respostaDoRegem(200);
    await new RegemAvisosService(
      p.prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { soReativar: true });
    expect(f).toHaveBeenCalledTimes(1);
    expect(
      JSON.parse(String((f.mock.calls[0][1] as RequestInit).body)).segredo,
    ).toBe(SEGREDO_ATUAL);

    // Token trocado → a rotina não religa (o registro morreu com o token velho).
    p = prismaCom({
      id: 'integ-1',
      ...DONO,
      avisos: estadoLigado({ registradoEm, resumoDoToken: 'outro' }),
    });
    f = respostaDoRegem(200);
    await new RegemAvisosService(
      p.prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { soReativar: true });
    expect(f).not.toHaveBeenCalled();
  });

  it('token novo + "Testar conexão" → segredo novo, e o antigo fica como anterior', async () => {
    const { prisma, atual } = prismaCom({
      id: 'integ-1',
      ...DONO,
      avisos: estadoLigado({ resumoDoToken: buscaDoSegredo('token-velho') }),
    });
    const f = respostaDoRegem(200);
    await new RegemAvisosService(
      prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { forcar: true });
    const enviado = JSON.parse(
      String((f.mock.calls[0][1] as RequestInit).body),
    ).segredo;
    expect(enviado).not.toBe(SEGREDO_ATUAL);
    const estado = lerEstadoDosAvisos(atual()!.avisos)!;
    expect(decifrar(estado.anterior!, CHAVE, CONTEXTO)).toBe(SEGREDO_ATUAL);
    expect(estado.trocadoEm).toBeTruthy();
    expect(estado.resumoDoToken).toBe(buscaDoSegredo(TOKEN));
  });

  it('outro registro gravou no meio (CAS falhou) → não vai ao Regem', async () => {
    const { prisma } = prismaCom(linhaSemAvisos());
    prisma.integracao.updateMany.mockResolvedValueOnce({ count: 0 });
    const f = respostaDoRegem(200);
    const situacao = await new RegemAvisosService(
      prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { forcar: true });
    expect(f).not.toHaveBeenCalled();
    expect(situacao.detalhe).toContain('em andamento');
  });

  it('sem a chave dos segredos no servidor → não liga (não teria onde guardar o segredo)', async () => {
    delete process.env.GOGEM_CHAVE_DOS_SEGREDOS;
    const { prisma } = prismaCom(linhaSemAvisos());
    const f = respostaDoRegem(200);
    const situacao = await new RegemAvisosService(
      prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).garantirRegistro(cfg(), { forcar: true });
    expect(f).not.toHaveBeenCalled();
    expect(situacao.ligados).toBe(false);
  });

  it('desligar: DELETE confirmado apaga o registro; sem confirmação, o registro fica', async () => {
    let p = prismaCom({ id: 'integ-1', ...DONO, avisos: estadoLigado() });
    let f = respostaDoRegem(204);
    let situacao = await new RegemAvisosService(
      p.prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).desligar(cfg());
    expect((f.mock.calls[0][1] as RequestInit).method).toBe('DELETE');
    expect(p.prisma.integracao.update.mock.calls[0][0].data.avisos).toBe(
      Prisma.DbNull,
    );
    expect(situacao.ligados).toBe(false);

    p = prismaCom({ id: 'integ-1', ...DONO, avisos: estadoLigado() });
    f = respostaDoRegem(500, { message: 'caiu' });
    situacao = await new RegemAvisosService(
      p.prisma as unknown as PrismaService,
      resolverFalso() as unknown as RegemConfigResolver,
    ).desligar(cfg());
    expect(p.prisma.integracao.update).not.toHaveBeenCalled();
    expect(situacao.detalhe).toContain('não desligados');
  });
});

describe('os dois avisos (§4 e §5)', () => {
  function inbound() {
    const cancelamento = { cancelarPorChave: vi.fn() };
    const imports = {
      sincronizarLinkados: vi.fn().mockResolvedValue({ alterados: 3 }),
    };
    const publicacao = { publicar: vi.fn().mockResolvedValue({}) };
    const s = new RegemInboundService(
      {} as never,
      imports as never,
      publicacao as never,
      cancelamento as never,
    );
    return { s, cancelamento, imports, publicacao };
  }
  const cancelado = (pedido: Record<string, unknown>) => ({
    tenantId: 't1',
    corpo: { tipo: 'pedido.cancelado', contrato: 1, loja_id: 'x', pedido },
  });

  it('pedido.cancelado → o cancelamento de hoje, com a chave e o motivo', async () => {
    const { s, cancelamento } = inbound();
    const resultado = {
      status: 'cancelado',
      pedidoId: 'p1',
      estorno: {
        feito: true,
        meio: 'pix',
        valorCentavos: 1000,
        refundId: 'r1',
        mensagem: 'ok',
      },
    };
    cancelamento.cancelarPorChave.mockResolvedValue(resultado);
    await expect(
      s.tratarAviso(
        cancelado({
          idempotencyKey: 'totem-1',
          regemComandaId: 'c1',
          motivo: 'Desistiu',
        }),
      ),
    ).resolves.toEqual(resultado);
    expect(cancelamento.cancelarPorChave).toHaveBeenCalledWith(
      { idempotencyKey: 'totem-1', regemComandaId: 'c1' },
      'Desistiu',
      'regem',
    );
  });

  it('o MESMO aviso repetido roda o cancelamento de novo e devolve o resultado atual (nunca 200 vazio)', async () => {
    const { s, cancelamento } = inbound();
    cancelamento.cancelarPorChave
      .mockResolvedValueOnce({
        status: 'cancelado',
        pedidoId: 'p1',
        estorno: {
          feito: false,
          meio: 'pix',
          valorCentavos: 1000,
          mensagem: 'MP fora',
        },
      })
      .mockResolvedValueOnce({
        status: 'cancelado',
        pedidoId: 'p1',
        estorno: {
          feito: true,
          meio: 'pix',
          valorCentavos: 1000,
          refundId: 'r1',
          mensagem: 'ok',
        },
      });
    const aviso = cancelado({ idempotencyKey: 'totem-1' });
    const primeiro = (await s.tratarAviso(aviso)) as {
      estorno: { feito: boolean };
    };
    const repetido = (await s.tratarAviso(aviso)) as {
      estorno: { feito: boolean };
    };
    expect(cancelamento.cancelarPorChave).toHaveBeenCalledTimes(2);
    expect(primeiro.estorno.feito).toBe(false);
    expect(repetido.estorno.feito).toBe(true);
  });

  it('pedido não encontrado → 422 pedido-nao-encontrado (não 404)', async () => {
    const { s, cancelamento } = inbound();
    cancelamento.cancelarPorChave.mockRejectedValue(
      new NotFoundException('Pedido não encontrado.'),
    );
    const erro = (await s
      .tratarAviso(cancelado({ idempotencyKey: 'nao-existe' }))
      .catch((e) => e)) as UnprocessableEntityException;
    expect(erro).toBeInstanceOf(UnprocessableEntityException);
    expect(erro.getResponse()).toEqual({
      code: 'pedido-nao-encontrado',
      message: 'Pedido não encontrado.',
    });
  });

  it('campo do pedido fora do contrato (tamanho) → 400', async () => {
    const { s, cancelamento } = inbound();
    await expect(
      s.tratarAviso(cancelado({ idempotencyKey: 'x'.repeat(121) })),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(cancelamento.cancelarPorChave).not.toHaveBeenCalled();
  });

  it('catalogo.publicar → { alterados } e republica', async () => {
    const { s, publicacao } = inbound();
    await expect(
      s.tratarAviso({
        tenantId: 't1',
        corpo: { tipo: 'catalogo.publicar', contrato: 1 },
      }),
    ).resolves.toEqual({ alterados: 3 });
    expect(publicacao.publicar).toHaveBeenCalledWith(null);
  });

  it('tipo desconhecido → 422', async () => {
    const { s } = inbound();
    const erro = (await s
      .tratarAviso({
        tenantId: 't1',
        corpo: { tipo: 'pedido.alterado', contrato: 1 },
      })
      .catch((e) => e)) as UnprocessableEntityException;
    expect(erro).toBeInstanceOf(UnprocessableEntityException);
    expect(erro.getResponse()).toMatchObject({ code: 'tipo-desconhecido' });
  });
});
