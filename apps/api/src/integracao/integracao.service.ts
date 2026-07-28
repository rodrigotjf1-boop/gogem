import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RegemConfigResolver } from '../integracoes/regem/regem-config.resolver';
import { RegemCatalogClient } from '../integracoes/regem/regem-catalog.client';
import {
  RegemImportService,
  type RegemImportResumo,
} from '../integracoes/regem/regem-import.service';
import { CONECTORES, SECRET_MASK, type Conector } from './conectores';
import { UpsertIntegracaoDto } from './dto/upsert-integracao.dto';

/** Campo de config já resolvido para exibição (segredo nunca vaza cru). */
export interface IntegracaoCampoView {
  key: string;
  label: string;
  secret: boolean;
  url?: boolean;
  ajuda?: string;
  /** Há valor guardado para este campo? */
  preenchido: boolean;
  /** Valor exibível: o valor real (não-segredo) ou máscara/'' (segredo). */
  valor: string;
}

/** Uma integração como o admin a vê (segredos mascarados). */
export interface IntegracaoView {
  tipo: string;
  nome: string;
  descricao: string;
  disponivel: boolean;
  importaCatalogo: boolean;
  ativo: boolean;
  /** Todos os campos preenchidos? */
  configurado: boolean;
  campos: IntegracaoCampoView[];
  nomePersonalizado: string | null;
  ultimoTeste: unknown;
}

/** Resultado de um teste de conexão. */
export interface TesteResultado {
  ok: boolean;
  detalhe: string;
  em: string;
}

/**
 * IntegracaoService — CRUD das integrações do tenant + testar/importar por
 * conector (Fase 2). O GoGeM é uma API aberta: os conectores são declarados em
 * `conectores.ts`; aqui ficam a persistência (tenant-scoped) e os handlers.
 *
 * Segurança: segredos (token, client secret) NUNCA voltam crus ao front — só
 * `preenchido`. No upsert, campo-segredo em branco = mantém o guardado (não
 * apaga sem querer ao reeditar).
 */
@Injectable()
export class IntegracaoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly resolver: RegemConfigResolver,
    private readonly catalog: RegemCatalogClient,
    private readonly regemImport: RegemImportService,
  ) {}

  /** Lista todos os conectores conhecidos, com o estado do tenant (mascarado). */
  async list(): Promise<IntegracaoView[]> {
    const rows = await this.prisma.integracao.findMany();
    const porTipo = new Map(rows.map((r) => [r.tipo, r]));
    return Object.values(CONECTORES).map((c) =>
      this.toView(c, porTipo.get(c.tipo)),
    );
  }

  /** Salva a config de um conector (merge de segredos) e retorna a view. */
  async upsert(
    tipo: string,
    dto: UpsertIntegracaoDto,
  ): Promise<IntegracaoView> {
    const conector = this.conectorDisponivel(tipo);

    const existente = await this.prisma.integracao.findFirst({
      where: { tipo },
    });
    const atual = (existente?.config ?? {}) as Record<string, string>;
    const config = this.mesclarConfig(conector, atual, dto.config ?? {});

    const configurado = conector.campos.every((f) =>
      (config[f.key] ?? '').trim() ? true : false,
    );
    const ativo = dto.ativo ?? existente?.ativo ?? false;
    if (ativo && !configurado) {
      throw new BadRequestException(
        'Preencha todos os campos da integração antes de ativá-la.',
      );
    }

    const nome = dto.nome ?? existente?.nome ?? null;
    const data = {
      config: config as Prisma.InputJsonValue,
      ativo,
      nome,
    };

    if (existente) {
      await this.prisma.integracao.update({
        where: { id: existente.id },
        data,
      });
    } else {
      // tenantId é injetado pelo middleware (§2).
      const create = { tipo, ...data } satisfies Omit<
        Prisma.IntegracaoUncheckedCreateInput,
        'tenantId'
      >;
      await this.prisma.integracao.create({
        data: create as Prisma.IntegracaoUncheckedCreateInput,
      });
    }
    return this.getView(tipo);
  }

  /** Testa a conexão do conector com a config guardada (mesmo não-ativa). */
  async testar(tipo: string): Promise<TesteResultado> {
    const conector = this.conectorDisponivel(tipo);
    if (tipo !== 'regem') {
      throw new BadRequestException(
        `Teste de conexão ainda não implementado para "${conector.nome}".`,
      );
    }

    let resultado: TesteResultado;
    try {
      const cfg = await this.resolver.resolve({ ignoreActive: true });
      const catalogo = await this.catalog.fetchCatalogoWith(cfg);
      const n = catalogo.produtos?.length ?? 0;
      resultado = {
        ok: true,
        detalhe: `Conexão ok — ${n} produto(s) no catálogo do Regem.`,
        em: new Date().toISOString(),
      };
    } catch (err) {
      resultado = {
        ok: false,
        detalhe: err instanceof Error ? err.message : String(err),
        em: new Date().toISOString(),
      };
    }

    // Persiste o último teste (best-effort; escopado por tenant).
    const row = await this.prisma.integracao.findFirst({ where: { tipo } });
    if (row) {
      await this.prisma.integracao.update({
        where: { id: row.id },
        data: { ultimoTeste: resultado as unknown as Prisma.InputJsonValue },
      });
    }
    return resultado;
  }

  /** Importa o catálogo do sistema externo para o rascunho do GoGeM. */
  async importar(tipo: string): Promise<RegemImportResumo> {
    const conector = this.conectorDisponivel(tipo);
    if (!conector.importaCatalogo || tipo !== 'regem') {
      throw new BadRequestException(
        `Importar catálogo ainda não disponível para "${conector.nome}".`,
      );
    }
    return this.regemImport.importar();
  }

  // ── internos ──────────────────────────────────────────────────────────────

  private conectorDisponivel(tipo: string): Conector {
    const c = CONECTORES[tipo];
    if (!c) throw new NotFoundException(`Conector "${tipo}" desconhecido.`);
    if (!c.disponivel) {
      throw new BadRequestException(
        `O conector "${c.nome}" ainda não está disponível.`,
      );
    }
    return c;
  }

  private async getView(tipo: string): Promise<IntegracaoView> {
    const row = await this.prisma.integracao.findFirst({ where: { tipo } });
    return this.toView(CONECTORES[tipo], row ?? undefined);
  }

  /** Aplica o merge de config respeitando segredos (branco = mantém). */
  private mesclarConfig(
    conector: Conector,
    atual: Record<string, string>,
    entrada: Record<string, string>,
  ): Record<string, string> {
    const out: Record<string, string> = { ...atual };
    for (const campo of conector.campos) {
      const recebido = entrada[campo.key];
      if (campo.secret) {
        // Segredo: só sobrescreve com um valor real (não vazio, não a máscara).
        const v = (recebido ?? '').trim();
        if (v && v !== SECRET_MASK) out[campo.key] = v;
      } else if (recebido !== undefined) {
        out[campo.key] = recebido.trim();
      }
    }
    // Descarta chaves fora do whitelist do conector.
    for (const k of Object.keys(out)) {
      if (!conector.campos.some((f) => f.key === k)) delete out[k];
    }
    return out;
  }

  private toView(
    conector: Conector,
    row?: {
      ativo: boolean;
      nome: string | null;
      config: unknown;
      ultimoTeste: unknown;
    },
  ): IntegracaoView {
    const config = (row?.config ?? {}) as Record<string, string>;
    const campos: IntegracaoCampoView[] = conector.campos.map((f) => {
      const bruto = (config[f.key] ?? '').trim();
      const preenchido = bruto.length > 0;
      return {
        key: f.key,
        label: f.label,
        secret: f.secret,
        url: f.url,
        ajuda: f.ajuda,
        preenchido,
        valor: f.secret ? (preenchido ? SECRET_MASK : '') : bruto,
      };
    });
    return {
      tipo: conector.tipo,
      nome: conector.nome,
      descricao: conector.descricao,
      disponivel: conector.disponivel,
      importaCatalogo: conector.importaCatalogo,
      ativo: row?.ativo ?? false,
      configurado: campos.every((c) => c.preenchido),
      campos,
      nomePersonalizado: row?.nome ?? null,
      ultimoTeste: row?.ultimoTeste ?? null,
    };
  }
}
