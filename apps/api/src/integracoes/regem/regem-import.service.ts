import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CardapioService } from '../../cardapio/cardapio.service';
import {
  RegemCatalogClient,
  type RegemGrupo,
  type RegemProduto,
} from './regem-catalog.client';
import { reaisToCentavos } from './reais-to-centavos';

/**
 * RegemImportService — capstone da integração Regem↔GoGeM (fatia 3).
 *
 * Puxa o catálogo do Regem e constrói/atualiza o catálogo-rascunho do GoGeM.
 *
 * Multi-tenant (CLAUDE.md §2): NENHUM método adiciona `tenantId` à mão — o
 * middleware `$use` do PrismaService injeta o tenant do contexto (a rota de
 * import é JWT-guarded, então o contexto sempre existe). Todos os
 * reads/writes são chamadas Prisma normais.
 *
 * De-para PDV (§4): o ref `regem` guarda o `codigo_pdv` (com que a venda e a
 * pausa chegam ao Regem) e o `regem_id` (id do produto no Regem, que o catálogo
 * manda). O produto casa PELO ID quando o ref já o tem — se o Regem trocar o
 * código, o ref acompanha (ERR-035: a troca de códigos do Regem em 20/10/2026
 * soltou 57 produtos e fez 4 espelharem OUTRO produto, porque o código antigo
 * deles virou o novo de outro). Ref antigo, sem id, casa pelo código e ganha o
 * id. Grupos e opções casam por `(produtoId, nome)` e `(grupoId, nome)`.
 *
 * Semântica v1: **aditivo/refresh** — cria o que falta e atualiza o que já
 * existe; NÃO deleta itens do GoGeM ausentes no Regem.
 */

/** Uma referência de de-para PDV persistida no Json (§4). */
interface ExternalRef {
  sistema: string;
  codigo_pdv: string;
  loja?: string;
  /** Id do produto no Regem (só no ref `regem` de produto). */
  regem_id?: string;
  [k: string]: unknown;
}

/** Vínculo de um produto GoGeM indexado para o import. */
interface Vinculo {
  id: string;
  externalRefs: ExternalRef[];
}

/** O que o Regem diz de um produto, para a sincronização. */
interface Desejado {
  codigo: string;
  regemId: string | null;
  precoCentavos: number;
  disponivel: boolean;
  nome: string;
  descricao: string | null;
}

/** Resumo do que o import criou/atualizou. */
export interface RegemImportResumo {
  geradoEm: string;
  categorias: { criadas: number; atualizadas: number };
  produtos: {
    criados: number;
    atualizados: number;
    ignoradosSemCodigo: number;
  };
  grupos: { criados: number; atualizados: number };
  opcoes: { criados: number; atualizados: number };
}

@Injectable()
export class RegemImportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly client: RegemCatalogClient,
    private readonly cardapios: CardapioService,
  ) {}

  /**
   * Executa o import para o tenant do contexto. `cardapioId` = cardápio-alvo
   * (Fase 3B): permite importar para o cardápio em preparação (migração de
   * sistema) sem tocar o ativo; ausente = cardápio ativo.
   */
  async importar(cardapioId?: string): Promise<RegemImportResumo> {
    const alvo = await this.cardapios.resolverAlvo(cardapioId);
    const catalogo = await this.client.fetchCatalogo();

    const resumo: RegemImportResumo = {
      geradoEm: catalogo.geradoEm,
      categorias: { criadas: 0, atualizadas: 0 },
      produtos: { criados: 0, atualizados: 0, ignoradosSemCodigo: 0 },
      grupos: { criados: 0, atualizados: 0 },
      opcoes: { criados: 0, atualizados: 0 },
    };

    const categoriaMap = await this.importCategorias(
      catalogo.categorias,
      resumo,
      alvo,
    );
    const idsNoCatalogo = new Set(
      catalogo.produtos
        .map(idDoRegem)
        .filter((id): id is string => id !== null),
    );
    const vinculos = await this.carregarVinculos(alvo, idsNoCatalogo);

    for (const rp of catalogo.produtos) {
      const codigo = (rp.codigo ?? '').trim();
      if (!codigo) {
        resumo.produtos.ignoradosSemCodigo += 1;
        continue;
      }
      const gogemProdutoId = await this.upsertProduto(
        rp,
        codigo,
        categoriaMap,
        vinculos,
        resumo,
        alvo,
      );
      await this.importGruposOpcoes(gogemProdutoId, rp.grupos, resumo);
    }

    return resumo;
  }

  /**
   * Sincroniza do Regem apenas os produtos JÁ LINKADOS — o Regem age como
   * "segundo admin": edições de preço, nome, descrição e pausa/disponibilidade
   * propagam ao GoGeM. NÃO cria produtos novos (isso é o `importar`) nem toca
   * campos só-GoGeM (selo, upsell, imagem, categoria). Atualiza apenas o que
   * mudou; devolve quantos foram alterados (o chamador republica só se
   * `alterados > 0`).
   *
   * Vínculo com `regem_id` casa pelo id: se o Regem trocou o código, o ref passa
   * ao código novo (conta como alterado — o cardápio publicado leva o código com
   * que o totem vende). Vínculo antigo, sem id, casa pelo código e ganha o id
   * (sem contar como alterado: nada muda para o totem).
   */
  async sincronizarLinkados(
    cardapioId?: string,
  ): Promise<{ verificados: number; alterados: number }> {
    const alvo = await this.cardapios.resolverAlvo(cardapioId);
    const catalogo = await this.client.fetchCatalogo();

    // Fonte da verdade configurável (por loja): por padrão o Regem espelha
    // preço e disponibilidade; a loja pode desligar cada um p/ gerir no GoGeM.
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem' },
    });
    const cfg = (integ?.config ?? {}) as {
      precoSegueRegem?: string;
      dispSegueRegem?: string;
    };
    const precoSegue = cfg.precoSegueRegem !== 'false'; // default: espelha
    const dispSegue = cfg.dispSegueRegem !== 'false';

    // Estado desejado (a partir do Regem), por id do produto e por código PDV.
    const porId = new Map<string, Desejado>();
    const porCodigo = new Map<string, Desejado>();
    for (const rp of catalogo.produtos) {
      const codigo = (rp.codigo ?? '').trim();
      if (!codigo) continue;
      const d: Desejado = {
        codigo,
        regemId: idDoRegem(rp),
        precoCentavos: reaisToCentavos(rp.precoVenda),
        disponivel: disponivelNoGogem(rp),
        nome: rp.nome,
        descricao: rp.descricao ?? null,
      };
      porCodigo.set(codigo, d);
      if (d.regemId) porId.set(d.regemId, d);
    }

    // Produtos GoGeM do cardápio-alvo, com os campos que podem mudar.
    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId: alvo },
      select: {
        id: true,
        nome: true,
        descricao: true,
        precoCentavos: true,
        disponivel: true,
        externalRefs: true,
      },
    });

    // Conflitos já registrados (F3): mapa (produtoId·campo) → estado.
    const conflitoMap = new Map<
      string,
      { id: string; status: string; valorRegem: string }
    >();
    for (const c of await this.prisma.catalogoConflito.findMany()) {
      conflitoMap.set(`${c.produtoId}·${c.campo}`, {
        id: c.id,
        status: c.status,
        valorRegem: c.valorRegem,
      });
    }

    let verificados = 0;
    let alterados = 0;
    for (const p of produtos) {
      const ref = refDoRegem(p.externalRefs);
      if (!ref) continue;
      const alvoRegem = casarNoRegem(ref, porId, porCodigo);
      if (!alvoRegem) continue; // produto não veio no catálogo do Regem
      verificados += 1;

      const patch: Record<string, unknown> = {};
      if (precoSegue && alvoRegem.precoCentavos !== p.precoCentavos)
        patch.precoCentavos = alvoRegem.precoCentavos;
      if (dispSegue && alvoRegem.disponivel !== p.disponivel)
        patch.disponivel = alvoRegem.disponivel;
      if (alvoRegem.nome !== p.nome) patch.nome = alvoRegem.nome;
      if ((alvoRegem.descricao ?? null) !== (p.descricao ?? null))
        patch.descricao = alvoRegem.descricao;
      const visivel = Object.keys(patch).length > 0;

      // O vínculo acompanha o Regem: código novo e/ou o id que faltava.
      const codigoMudou = alvoRegem.codigo !== ref.codigo;
      const regemId = alvoRegem.regemId ?? ref.regemId;
      if (codigoMudou || regemId !== ref.regemId) {
        patch.externalRefs = comRefDoRegem(
          lerRefs(p.externalRefs),
          alvoRegem.codigo,
          regemId,
        ) as unknown as Prisma.InputJsonValue;
      }

      if (Object.keys(patch).length) {
        await this.prisma.produto.update({ where: { id: p.id }, data: patch });
        if (visivel || codigoMudou) alterados += 1;
      }

      // F3 — quando a loja é a fonte de um campo e o Regem diverge, vira fila.
      await this.conciliar(
        conflitoMap,
        p.id,
        alvoRegem.codigo,
        'preco',
        String(alvoRegem.precoCentavos),
        String(p.precoCentavos),
        precoSegue,
      );
      await this.conciliar(
        conflitoMap,
        p.id,
        alvoRegem.codigo,
        'disponivel',
        String(alvoRegem.disponivel),
        String(p.disponivel),
        dispSegue,
      );
    }
    return { verificados, alterados };
  }

  /**
   * F3 — concilia um campo com a fila de conflitos:
   * - segue o Regem (ou valores iguais) → limpa qualquer conflito do campo;
   * - loja é a fonte e diverge → abre/atualiza o conflito, salvo se estiver
   *   "ignorado" para exatamente este valor do Regem (não re-alerta à toa).
   */
  private async conciliar(
    mapa: Map<string, { id: string; status: string; valorRegem: string }>,
    produtoId: string,
    codigo: string,
    campo: string,
    valorRegem: string,
    valorGogem: string,
    segueRegem: boolean,
  ): Promise<void> {
    const ex = mapa.get(`${produtoId}·${campo}`);
    const diverge = valorRegem !== valorGogem;
    if (segueRegem || !diverge) {
      if (ex)
        await this.prisma.catalogoConflito.delete({ where: { id: ex.id } });
      return;
    }
    if (ex && ex.status === 'ignorado' && ex.valorRegem === valorRegem) return;
    if (ex) {
      await this.prisma.catalogoConflito.update({
        where: { id: ex.id },
        data: { status: 'aberto', valorRegem, valorGogem, codigo },
      });
    } else {
      const data = {
        produtoId,
        codigo,
        campo,
        valorRegem,
        valorGogem,
      } satisfies Omit<Prisma.CatalogoConflitoUncheckedCreateInput, 'tenantId'>;
      await this.prisma.catalogoConflito.create({
        data: data as Prisma.CatalogoConflitoUncheckedCreateInput,
      });
    }
  }

  /**
   * F2 do espelho — diferenças entre o Regem e o GoGeM (sem escrever nada):
   * - `novos`: produtos do Regem SEM par no GoGeM (candidatos a importar), fora
   *   os que a loja marcou "ignorar" (`config.ignorados`).
   * - `orfaos`: produtos GoGeM linkados sem par no catálogo do Regem — pelo id,
   *   quando o vínculo o tem; senão pelo código (candidatos a pausar/excluir).
   *   Produto cujo código o Regem trocou NÃO é órfão: o id ainda casa.
   */
  async novidades(cardapioId?: string): Promise<{
    novos: { codigo: string; nome: string; precoCentavos: number }[];
    orfaos: { id: string; nome: string; codigo: string }[];
  }> {
    const alvo = await this.cardapios.resolverAlvo(cardapioId);
    const catalogo = await this.client.fetchCatalogo();
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem' },
    });
    const cfg = (integ?.config ?? {}) as { ignorados?: unknown };
    const ignorados = new Set(
      (Array.isArray(cfg.ignorados) ? cfg.ignorados : []).map((c) =>
        String(c).trim(),
      ),
    );

    const regemPorCodigo = new Map<string, RegemProduto>();
    const porId = new Map<string, { codigo: string }>();
    const porCodigo = new Map<string, { codigo: string }>();
    for (const rp of catalogo.produtos) {
      const c = (rp.codigo ?? '').trim();
      if (!c) continue;
      regemPorCodigo.set(c, rp);
      porCodigo.set(c, { codigo: c });
      const id = idDoRegem(rp);
      if (id) porId.set(id, { codigo: c });
    }

    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId: alvo },
      select: { id: true, nome: true, externalRefs: true },
    });
    const vinculados = new Set<string>();
    const orfaos: { id: string; nome: string; codigo: string }[] = [];
    for (const p of produtos) {
      const ref = refDoRegem(p.externalRefs);
      if (!ref) continue;
      const casado = casarNoRegem(ref, porId, porCodigo);
      if (casado) vinculados.add(casado.codigo);
      else orfaos.push({ id: p.id, nome: p.nome, codigo: ref.codigo });
    }

    const novos: { codigo: string; nome: string; precoCentavos: number }[] = [];
    for (const [codigo, rp] of regemPorCodigo) {
      if (vinculados.has(codigo) || ignorados.has(codigo)) continue;
      novos.push({
        codigo,
        nome: rp.nome,
        precoCentavos: reaisToCentavos(rp.precoVenda),
      });
    }
    return { novos, orfaos };
  }

  /** F2 — marca um código do Regem como "ignorar" (some da lista de novidades). */
  async ignorarNovidade(codigo: string): Promise<{ ignorados: string[] }> {
    const alvo = (codigo ?? '').trim();
    if (!alvo) throw new BadRequestException('Código inválido.');
    const integ = await this.prisma.integracao.findFirst({
      where: { tipo: 'regem' },
    });
    if (!integ) {
      throw new BadRequestException('Integração Regem não configurada.');
    }
    const cfg = (integ.config ?? {}) as Record<string, unknown>;
    const atuais = Array.isArray(cfg.ignorados)
      ? cfg.ignorados.map((c) => String(c))
      : [];
    const ignorados = [...new Set([...atuais, alvo])];
    await this.prisma.integracao.update({
      where: { id: integ.id },
      data: { config: { ...cfg, ignorados } as Prisma.InputJsonValue },
    });
    return { ignorados };
  }

  /** F3 — conflitos abertos (loja é a fonte e o Regem diverge), com o nome. */
  async conflitos(): Promise<
    Array<{
      id: string;
      produtoId: string;
      nome: string;
      codigo: string;
      campo: string;
      valorRegem: string;
      valorGogem: string;
    }>
  > {
    const rows = await this.prisma.catalogoConflito.findMany({
      where: { status: 'aberto' },
      orderBy: { updatedAt: 'desc' },
    });
    if (rows.length === 0) return [];
    const produtos = await this.prisma.produto.findMany({
      where: { id: { in: [...new Set(rows.map((r) => r.produtoId))] } },
      select: { id: true, nome: true },
    });
    const nomes = new Map(produtos.map((p) => [p.id, p.nome]));
    return rows.map((r) => ({
      id: r.id,
      produtoId: r.produtoId,
      nome: nomes.get(r.produtoId) ?? r.produtoId,
      codigo: r.codigo,
      campo: r.campo,
      valorRegem: r.valorRegem,
      valorGogem: r.valorGogem,
    }));
  }

  /**
   * F3 — resolve um conflito: 'regem' aplica o valor do Regem no produto e
   * fecha; 'gogem' silencia (mantém o valor da loja até o Regem mudar de novo).
   */
  async resolverConflito(
    id: string,
    escolha: 'regem' | 'gogem',
  ): Promise<{ id: string }> {
    const c = await this.prisma.catalogoConflito.findFirst({ where: { id } });
    if (!c) throw new BadRequestException('Conflito não encontrado.');
    if (escolha === 'regem') {
      const patch =
        c.campo === 'preco'
          ? { precoCentavos: Number(c.valorRegem) || 0 }
          : { disponivel: c.valorRegem === 'true' };
      await this.prisma.produto.update({
        where: { id: c.produtoId },
        data: patch,
      });
      await this.prisma.catalogoConflito.delete({ where: { id: c.id } });
    } else {
      await this.prisma.catalogoConflito.update({
        where: { id: c.id },
        data: { status: 'ignorado' },
      });
    }
    return { id };
  }

  /**
   * Casa categorias por `nome` (trim, case-insensitive) no tenant; cria as
   * ausentes (ordem do Regem) e atualiza a ordem das existentes. Retorna o
   * mapa `regemCategoriaId → gogemCategoriaId`.
   */
  private async importCategorias(
    categorias: { id: string; nome: string; ordem: number }[],
    resumo: RegemImportResumo,
    cardapioId: string,
  ): Promise<Map<string, string>> {
    const existentes = await this.prisma.categoria.findMany({
      where: { cardapioId },
    });
    const porNome = new Map<string, { id: string }>();
    for (const c of existentes) porNome.set(normalizar(c.nome), { id: c.id });

    const map = new Map<string, string>();
    for (const rc of categorias) {
      const chave = normalizar(rc.nome);
      const existente = porNome.get(chave);
      if (existente) {
        await this.prisma.categoria.update({
          where: { id: existente.id },
          data: { ordem: rc.ordem ?? 0 },
        });
        resumo.categorias.atualizadas += 1;
        map.set(rc.id, existente.id);
      } else {
        const data = {
          nome: rc.nome,
          ordem: rc.ordem ?? 0,
          cardapioId,
        } satisfies Omit<Prisma.CategoriaUncheckedCreateInput, 'tenantId'>;
        const criada = await this.prisma.categoria.create({
          data: data as Prisma.CategoriaUncheckedCreateInput,
        });
        resumo.categorias.criadas += 1;
        porNome.set(chave, { id: criada.id });
        map.set(rc.id, criada.id);
      }
    }
    return map;
  }

  /**
   * Carrega os produtos do cardápio-alvo e indexa o vínculo regem: pelo
   * `regem_id` quando ele ainda está no catálogo do Regem; senão (ref antigo sem
   * id, ou id que sumiu do Regem) pelo `codigo_pdv` — só esses podem ser
   * religados por código, para um produto do Regem nunca tomar o par de outro.
   */
  private async carregarVinculos(
    cardapioId: string,
    idsNoCatalogo: Set<string>,
  ): Promise<{ porId: Map<string, Vinculo>; porCodigo: Map<string, Vinculo> }> {
    const produtos = await this.prisma.produto.findMany({
      where: { cardapioId },
    });
    const porId = new Map<string, Vinculo>();
    const porCodigo = new Map<string, Vinculo>();
    for (const p of produtos) {
      const ref = refDoRegem(p.externalRefs);
      if (!ref) continue;
      const v = { id: p.id, externalRefs: lerRefs(p.externalRefs) };
      if (ref.regemId && idsNoCatalogo.has(ref.regemId))
        porId.set(ref.regemId, v);
      else porCodigo.set(ref.codigo, v);
    }
    return { porId, porCodigo };
  }

  /**
   * Upsert de um produto pelo vínculo regem (id; senão código). Cria se
   * ausente, senão atualiza — o ref fica com o código atual e o id do Regem.
   * Preserva refs não-regem ao atualizar. Retorna o id GoGeM.
   */
  private async upsertProduto(
    rp: RegemProduto,
    codigo: string,
    categoriaMap: Map<string, string>,
    vinculos: { porId: Map<string, Vinculo>; porCodigo: Map<string, Vinculo> },
    resumo: RegemImportResumo,
    cardapioId: string,
  ): Promise<string> {
    const precoCentavos = reaisToCentavos(rp.precoVenda);
    const disponivel = disponivelNoGogem(rp);
    const categoriaId = rp.categoriaId
      ? (categoriaMap.get(rp.categoriaId) ?? null)
      : null;
    // Foto do Regem (URL pública do Supabase). Só absolutas; quando ausente NÃO
    // apagamos uma imagem custom já enviada no GoGeM (só grava quando há uma).
    const imagemUrl = urlPublicaOuNull(rp.imagem);

    const regemId = idDoRegem(rp);
    const existente =
      (regemId ? vinculos.porId.get(regemId) : undefined) ??
      vinculos.porCodigo.get(codigo);
    if (existente) {
      const externalRefs = comRefDoRegem(
        existente.externalRefs,
        codigo,
        regemId,
      );
      if (regemId) {
        vinculos.porId.set(regemId, { id: existente.id, externalRefs });
      }
      await this.prisma.produto.update({
        where: { id: existente.id },
        data: {
          nome: rp.nome,
          descricao: rp.descricao ?? null,
          precoCentavos,
          disponivel,
          categoriaId,
          ...(imagemUrl ? { imagemUrl } : {}),
          externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
        },
      });
      resumo.produtos.atualizados += 1;
      return existente.id;
    }

    const externalRefs = comRefDoRegem([], codigo, regemId);
    const data = {
      nome: rp.nome,
      descricao: rp.descricao ?? null,
      precoCentavos,
      disponivel,
      categoriaId,
      imagemUrl,
      cardapioId,
      externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
    } satisfies Omit<Prisma.ProdutoUncheckedCreateInput, 'tenantId'>;
    const criado = await this.prisma.produto.create({
      data: data as Prisma.ProdutoUncheckedCreateInput,
    });
    resumo.produtos.criados += 1;
    // Indexa para não recriar caso o mesmo produto apareça duplicado no payload.
    const novo = { id: criado.id, externalRefs };
    if (regemId) vinculos.porId.set(regemId, novo);
    else vinculos.porCodigo.set(codigo, novo);
    return criado.id;
  }

  /**
   * Importa etapas e opções de um produto. Etapas são REUTILIZÁVEIS: casa por
   * nome entre as JÁ VINCULADAS ao produto (via `ProdutoComplemento`); cria uma
   * etapa nova + vínculo quando não existe. Opções casam por `(grupoId, nome)`.
   */
  private async importGruposOpcoes(
    produtoId: string,
    grupos: RegemGrupo[],
    resumo: RegemImportResumo,
  ): Promise<void> {
    const links = await this.prisma.produtoComplemento.findMany({
      where: { produtoId },
      include: { grupo: true },
    });
    const grupoPorNome = new Map<string, { id: string }>();
    for (const l of links) {
      grupoPorNome.set(normalizar(l.grupo.nome), { id: l.grupo.id });
    }
    let proximaOrdem = links.length;

    for (const rg of grupos ?? []) {
      let grupoId: string;
      const existente = grupoPorNome.get(normalizar(rg.nome));
      if (existente) {
        await this.prisma.complementoGrupo.update({
          where: { id: existente.id },
          data: {
            nome: rg.nome,
            min: rg.min ?? 0,
            max: rg.max ?? null,
            obrigatorio: rg.obrigatorio ?? false,
          },
        });
        resumo.grupos.atualizados += 1;
        grupoId = existente.id;
      } else {
        const grupoData = {
          nome: rg.nome,
          min: rg.min ?? 0,
          max: rg.max ?? null,
          obrigatorio: rg.obrigatorio ?? false,
        } satisfies Omit<
          Prisma.ComplementoGrupoUncheckedCreateInput,
          'tenantId'
        >;
        const criado = await this.prisma.complementoGrupo.create({
          data: grupoData as Prisma.ComplementoGrupoUncheckedCreateInput,
        });
        const linkData = {
          produtoId,
          grupoId: criado.id,
          ordem: rg.ordem ?? proximaOrdem++,
        } satisfies Omit<
          Prisma.ProdutoComplementoUncheckedCreateInput,
          'tenantId'
        >;
        await this.prisma.produtoComplemento.create({
          data: linkData as Prisma.ProdutoComplementoUncheckedCreateInput,
        });
        resumo.grupos.criados += 1;
        grupoId = criado.id;
        grupoPorNome.set(normalizar(rg.nome), { id: grupoId });
      }
      await this.importOpcoes(grupoId, rg, resumo);
    }
  }

  /** Upsert das opções de um grupo, casadas por `(grupoId, nome)`. */
  private async importOpcoes(
    grupoId: string,
    rg: RegemGrupo,
    resumo: RegemImportResumo,
  ): Promise<void> {
    const opcoesExistentes = await this.prisma.complementoOpcao.findMany({
      where: { grupoId },
    });
    const opcaoPorNome = new Map<string, { id: string }>();
    for (const o of opcoesExistentes) {
      opcaoPorNome.set(normalizar(o.nome), { id: o.id });
    }

    for (const ro of rg.opcoes ?? []) {
      const precoCentavosDelta = reaisToCentavos(ro.precoDelta);
      const externalRefs: ExternalRef[] = ro.codigoPdv
        ? [{ sistema: 'regem', codigo_pdv: ro.codigoPdv }]
        : [];
      const existente = opcaoPorNome.get(normalizar(ro.nome));
      if (existente) {
        await this.prisma.complementoOpcao.update({
          where: { id: existente.id },
          data: {
            nome: ro.nome,
            precoCentavosDelta,
            ordem: ro.ordem ?? 0,
            externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
          },
        });
        resumo.opcoes.atualizados += 1;
      } else {
        const data = {
          grupoId,
          nome: ro.nome,
          precoCentavosDelta,
          disponivel: true,
          ordem: ro.ordem ?? 0,
          externalRefs: externalRefs as unknown as Prisma.InputJsonValue,
        } satisfies Omit<
          Prisma.ComplementoOpcaoUncheckedCreateInput,
          'tenantId'
        >;
        await this.prisma.complementoOpcao.create({
          data: data as Prisma.ComplementoOpcaoUncheckedCreateInput,
        });
        resumo.opcoes.criados += 1;
        opcaoPorNome.set(normalizar(ro.nome), { id: 'novo' });
      }
    }
  }
}

/** Canais do Regem que representam o totem/GoGeM (pausa reflete no GoGeM). */
const CANAIS_GOGEM = ['gogem', 'totem'];

/**
 * Disponibilidade do produto no GoGeM a partir do estado do Regem (Fase 4,
 * Regem→GoGeM): indisponível se inativo, fora do cardápio, esgotado (estoque)
 * ou com o canal do totem pausado. Pausar no Regem some do totem no próximo sync.
 */
export function disponivelNoGogem(rp: RegemProduto): boolean {
  if (rp.ativo === false) return false;
  if (!rp.disponivelCardapio) return false;
  if (rp.pausadoEstoque === true) return false;
  const canais = Array.isArray(rp.canaisPausados)
    ? rp.canaisPausados.map((c) => String(c).toLowerCase())
    : [];
  if (canais.some((c) => CANAIS_GOGEM.includes(c))) return false;
  return true;
}

/** Normaliza um nome para casamento: trim + lower-case. */
function normalizar(nome: string): string {
  return (nome ?? '').trim().toLowerCase();
}

/**
 * URL de imagem só se for ABSOLUTA (http/https) — o GoGeM serve a foto direto
 * dessa URL (Supabase público do Regem). Refs relativas/vazias viram null para
 * não gravar caminho quebrado.
 */
function urlPublicaOuNull(raw: string | null | undefined): string | null {
  const s = (raw ?? '').trim();
  return /^https?:\/\//i.test(s) ? s : null;
}

/**
 * O vínculo regem do produto (código PDV + id no Regem, quando já gravado), ou
 * null se o produto não tem ref regem com código.
 */
function refDoRegem(
  raw: unknown,
): { codigo: string; regemId: string | null } | null {
  const ref = lerRefs(raw).find((r) => r.sistema === 'regem' && r.codigo_pdv);
  const codigo = ref ? ref.codigo_pdv.trim() : '';
  if (!ref || !codigo) return null;
  const id = typeof ref.regem_id === 'string' ? ref.regem_id.trim() : '';
  return { codigo, regemId: id || null };
}

/** Id do produto no catálogo do Regem (null se o Regem não mandou). */
function idDoRegem(rp: RegemProduto): string | null {
  const id = typeof rp.id === 'string' ? rp.id.trim() : '';
  return id || null;
}

/**
 * Acha no catálogo do Regem o par de um vínculo: pelo id quando o vínculo o tem
 * (acompanha a troca de código; id que sumiu = sem par), senão pelo código. Se o
 * catálogo veio SEM nenhum id (Regem antigo), o vínculo com id cai para o código.
 */
function casarNoRegem<T>(
  ref: { codigo: string; regemId: string | null },
  porId: Map<string, T>,
  porCodigo: Map<string, T>,
): T | undefined {
  if (ref.regemId && porId.size > 0) return porId.get(ref.regemId);
  return porCodigo.get(ref.codigo);
}

/** Lê o Json de `externalRefs` como array de refs (defensivo). */
function lerRefs(raw: unknown): ExternalRef[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (r): r is ExternalRef =>
      !!r &&
      typeof r === 'object' &&
      typeof (r as Record<string, unknown>).sistema === 'string' &&
      typeof (r as Record<string, unknown>).codigo_pdv === 'string',
  );
}

/**
 * Garante um único ref regem com o `codigo_pdv` (e o `regem_id`, quando
 * conhecido) informados, preservando os refs de outros sistemas (não duplica;
 * não clobbera não-regem).
 */
function comRefDoRegem(
  existing: ExternalRef[],
  codigoPdv: string,
  regemId: string | null,
): ExternalRef[] {
  const naoRegem = existing.filter((r) => r.sistema !== 'regem');
  const ref: ExternalRef = { sistema: 'regem', codigo_pdv: codigoPdv };
  if (regemId) ref.regem_id = regemId;
  return [...naoRegem, ref];
}
