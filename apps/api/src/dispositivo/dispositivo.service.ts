import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes, randomInt } from 'node:crypto';
import { Prisma, type Dispositivo } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { CreateDispositivoDto } from './dto/create-dispositivo.dto';
import {
  EnderecoInvalido,
  normalizarCaPem,
  normalizarEnderecoServidor,
} from './endereco-servidor';
import { HeartbeatDto } from './dto/heartbeat.dto';

/** Validade do código de pareamento (uso único). */
const CODIGO_TTL_MS = 15 * 60 * 1000; // 15 min

/**
 * Campos expostos ao admin — NUNCA o token (segredo do dispositivo). `tenantId`
 * é omitido: todas as linhas já são do tenant do chamador (redundante).
 */
const DISPOSITIVO_SELECT = {
  id: true,
  unidadeId: true,
  nome: true,
  tipo: true,
  pareado: true,
  codigoPareamento: true,
  codigoExpiraEm: true,
  ativo: true,
  ultimoHeartbeat: true,
  ultimoStatus: true,
  pointDeviceId: true,
  apiBase: true,
  caPem: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.DispositivoSelect;

/** Resposta da emissão de código (criar / reparear): mostra o código UMA vez. */
export interface CodigoEmitido {
  id: string;
  nome: string;
  codigoPareamento: string;
  codigoExpiraEm: Date;
}

/**
 * DispositivoService — CRUD de dispositivos (totens) + pareamento (issue #12.1).
 *
 * Multi-tenant (CLAUDE.md §2): os métodos do admin NÃO adicionam `tenantId` à
 * mão — o `tenantScopeMiddleware` injeta o tenant do contexto (essas rotas
 * ficam atrás do JwtAuthGuard). O pareamento público é a exceção: roda em
 * `TenantContext.runAsSystem` (lookup GLOBAL por código, antes de existir
 * contexto de tenant), espelhando o bootstrap do AuthService.
 */
@Injectable()
export class DispositivoService {
  constructor(private readonly prisma: PrismaService) {}

  /** Gera um código de pareamento de 6 dígitos (uso único). */
  private gerarCodigo(): string {
    return String(randomInt(0, 1_000_000)).padStart(6, '0');
  }

  /**
   * Cria um dispositivo (não pareado) e emite um código de pareamento. O
   * `tenantId` é injetado pelo middleware (§2) — não entra no payload.
   */
  async create(dto: CreateDispositivoDto): Promise<CodigoEmitido> {
    const codigoPareamento = this.gerarCodigo();
    const codigoExpiraEm = new Date(Date.now() + CODIGO_TTL_MS);

    const data = {
      nome: dto.nome,
      tipo: dto.tipo ?? 'totem',
      unidadeId: dto.unidadeId ?? null,
      pareado: false,
      codigoPareamento,
      codigoExpiraEm,
    } satisfies Omit<Prisma.DispositivoUncheckedCreateInput, 'tenantId'>;

    const dispositivo = await this.prisma.dispositivo.create({
      data: data as Prisma.DispositivoUncheckedCreateInput,
      select: {
        id: true,
        nome: true,
        codigoPareamento: true,
        codigoExpiraEm: true,
      },
    });

    return {
      id: dispositivo.id,
      nome: dispositivo.nome,
      codigoPareamento: dispositivo.codigoPareamento as string,
      codigoExpiraEm: dispositivo.codigoExpiraEm as Date,
    };
  }

  /** Lista os dispositivos do tenant — SEM o token (segredo). */
  list() {
    return this.prisma.dispositivo.findMany({
      orderBy: [{ createdAt: 'desc' }],
      select: DISPOSITIVO_SELECT,
    });
  }

  /**
   * Vincula (ou desvincula) a maquininha Point deste totem (modo PDV
   * multi-terminal). Vazio/nulo = usa o device_id padrão da loja.
   */
  async vincularMaquininha(id: string, pointDeviceId: string | null) {
    await this.getOne(id);
    return this.prisma.dispositivo.update({
      where: { id },
      data: { pointDeviceId: pointDeviceId?.trim() || null },
      select: DISPOSITIVO_SELECT,
    });
  }

  /**
   * G1 — define (ou limpa, com vazio/nulo) o endereço do servidor da loja para ESTE
   * totem. Vale a partir do PRÓXIMO pareamento: o aparelho já pareado guardou o destino
   * que recebeu, então trocar de destino é repareamento, não edição silenciosa — assim
   * não se muda o caminho de um totem que está no meio de uma venda.
   */
  async definirServidor(
    id: string,
    apiBase: string | null,
    caPem?: string | null,
  ) {
    await this.getOne(id);
    // A validação lança uma exceção PRÓPRIA (o normalizador é puro, não conhece HTTP).
    // Sem traduzir aqui, o Nest não reconhece e devolve 500 "Internal server error" —
    // erro de digitação do gestor viraria "problema no servidor", sem dizer o que houve.
    let valor: string | null = null;
    try {
      valor = (apiBase ?? '').trim()
        ? normalizarEnderecoServidor(apiBase as string)
        : null;
    } catch (e) {
      if (e instanceof EnderecoInvalido)
        throw new BadRequestException(e.message);
      throw e;
    }
    // K2 — certificado da autoridade do servidor. Sem endereço não há o que confiar,
    // então limpar o endereço limpa o certificado junto (não sobra credencial órfã).
    let certificado: string | null = null;
    if (valor) {
      try {
        certificado = (caPem ?? '').trim()
          ? normalizarCaPem(caPem as string)
          : null;
      } catch (e) {
        if (e instanceof EnderecoInvalido)
          throw new BadRequestException(e.message);
        throw e;
      }
    }
    return this.prisma.dispositivo.update({
      where: { id },
      data: { apiBase: valor, caPem: certificado },
      select: DISPOSITIVO_SELECT,
    });
  }

  /** Garante existência + escopo de tenant (404 caso contrário). */
  private async getOne(id: string): Promise<Dispositivo> {
    const dispositivo = await this.prisma.dispositivo.findFirst({
      where: { id },
    });
    if (!dispositivo) {
      throw new NotFoundException('Dispositivo não encontrado.');
    }
    return dispositivo;
  }

  /**
   * Revoga um dispositivo: `ativo = false`. O token deixa de valer no
   * DeviceTokenGuard (exige `ativo`).
   */
  async revogar(id: string) {
    await this.getOne(id);
    return this.prisma.dispositivo.update({
      where: { id },
      data: { ativo: false },
      select: DISPOSITIVO_SELECT,
    });
  }

  /**
   * Re-pareia: gera um novo código e limpa o token/pareamento anterior (o
   * dispositivo volta a poder ser pareado). Mantém `ativo` como está.
   */
  async reparear(id: string): Promise<CodigoEmitido> {
    const atual = await this.getOne(id);
    const codigoPareamento = this.gerarCodigo();
    const codigoExpiraEm = new Date(Date.now() + CODIGO_TTL_MS);

    await this.prisma.dispositivo.update({
      where: { id },
      data: {
        token: null,
        pareado: false,
        codigoPareamento,
        codigoExpiraEm,
      },
    });

    return { id, nome: atual.nome, codigoPareamento, codigoExpiraEm };
  }

  /**
   * Pareamento público (SEM auth): troca o código por um token de dispositivo.
   *
   * Lookup GLOBAL por código via `TenantContext.runAsSystem` (não há tenant no
   * contexto ainda — espelha o login do AuthService). Valida: código existe,
   * não expirou, dispositivo `ativo`, ainda não pareado. Qualquer falha →
   * 400 genérico (não revela qual condição falhou). Sucesso: grava o token,
   * marca `pareado`, limpa o código e retorna `{ token, nome }` UMA vez.
   *
   * Segurança: o endpoint público tem rate-limit apertado (10/min por IP, ver
   * DispositivoPublicoController) contra brute-force do código de 6 dígitos.
   */
  /**
   * G1 — o pareamento entrega o DESTINO junto com a credencial.
   *
   * Antes o host vivia dentro do APK (`--dart-define=GOGEM_API_URL`), então apontar um
   * totem para o servidor da loja exigia gerar e instalar um APK novo, por loja. Agora o
   * aparelho pergunta ao parear: `apiBase` preenchido = fala com o servidor da loja;
   * vazio = nuvem, que é o comportamento de sempre para quem não tem servidor local.
   */
  async parear(codigo: string): Promise<{
    token: string;
    nome: string;
    apiBase: string | null;
    caPem: string | null;
    modo: 'servidor' | 'nuvem';
  }> {
    const falha = new BadRequestException('Código inválido ou expirado.');

    return TenantContext.runAsSystem(async () => {
      const dispositivo = await this.prisma.dispositivo.findFirst({
        where: { codigoPareamento: codigo },
      });

      if (
        !dispositivo ||
        !dispositivo.ativo ||
        dispositivo.pareado ||
        !dispositivo.codigoExpiraEm ||
        dispositivo.codigoExpiraEm.getTime() < Date.now()
      ) {
        throw falha;
      }

      const token = randomBytes(32).toString('hex');

      // Escopo direto por id (evita corrida com outro código); runAsSystem
      // dispensa o tenant no contexto, mas a linha é única por id.
      await this.prisma.dispositivo.updateMany({
        where: { id: dispositivo.id, pareado: false, ativo: true },
        data: {
          token,
          pareado: true,
          codigoPareamento: null,
          codigoExpiraEm: null,
        },
      });

      return {
        token,
        nome: dispositivo.nome,
        apiBase: dispositivo.apiBase ?? null,
        caPem: dispositivo.caPem ?? null,
        modo: dispositivo.apiBase ? 'servidor' : 'nuvem',
      };
    });
  }

  /**
   * Heartbeat do totem (device-authed): grava o "sinal de vida" + o estado
   * reportado. Roda sob o contexto de tenant do dispositivo (o middleware
   * escopa a linha por tenant); o `id` garante que atualiza a própria linha.
   */
  async heartbeat(
    deviceId: string,
    status: HeartbeatDto,
  ): Promise<{ ok: true }> {
    await this.prisma.dispositivo.update({
      where: { id: deviceId },
      data: {
        ultimoHeartbeat: new Date(),
        ultimoStatus: { ...status } as Prisma.InputJsonValue,
      },
    });
    return { ok: true };
  }
}
