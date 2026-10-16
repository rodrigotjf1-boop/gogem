import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TenantContext } from '../tenant/tenant-context';
import { CONECTORES } from './conectores';
import {
  ENV_CHAVE_DOS_SEGREDOS,
  chaveDosSegredos,
  selarConfig,
} from './segredos';

/** O que uma passada da migração fez (só contagens — nunca valores). */
export interface ResumoDaMigracaoDeSegredos {
  /** Linhas gravadas nesta passada. */
  gravadas: number;
  /** Segredos que passaram do claro para a cifra. */
  cifrados: number;
  /** Segredos que seguem em claro por falta de chave. */
  emClaro: number;
  /** Linhas que mudaram entre a leitura e a gravação (ficam para a próxima). */
  adiadas: number;
}

/**
 * Migração dos segredos antigos, ao subir a API: cifra todo campo-segredo
 * ainda em claro e preenche o resumo de busca do token do Regem.
 *
 * - Idempotente: o que já está cifrado e com resumo não é tocado.
 * - Grava só se a linha não mudou desde a leitura (config e resumo iguais no
 *   banco); se mudou, fica para a próxima subida.
 * - Sem a chave: preenche só o resumo (a entrada do Regem passa a achar a
 *   empresa por ele) e avisa no log quantos segredos seguem em claro.
 * - Não trava a subida e nunca rejeita: a falha fica no log.
 */
@Injectable()
export class SegredosMigracao implements OnApplicationBootstrap {
  private readonly logger = new Logger(SegredosMigracao.name);

  constructor(private readonly prisma: PrismaService) {}

  onApplicationBootstrap(): void {
    if (process.env.NODE_ENV === 'test') return;
    void this.migrar();
  }

  async migrar(
    chave: Buffer | null = chaveDosSegredos(),
  ): Promise<ResumoDaMigracaoDeSegredos> {
    const resumo: ResumoDaMigracaoDeSegredos = {
      gravadas: 0,
      cifrados: 0,
      emClaro: 0,
      adiadas: 0,
    };
    try {
      if (!chave) {
        this.logger.warn(
          (process.env[ENV_CHAVE_DOS_SEGREDOS] ?? '').trim()
            ? `${ENV_CHAVE_DOS_SEGREDOS} em formato inválido (precisa de 32 bytes em base64): segredos novos serão recusados.`
            : `${ENV_CHAVE_DOS_SEGREDOS} ausente: segredos novos serão recusados.`,
        );
      }
      // Callback `async` com `await` (como no poller): com callback síncrono a
      // consulta do Prisma roda fora do contexto de sistema (ERR-031).
      const linhas = await TenantContext.runAsSystem(async () => {
        const todas = await this.prisma.integracao.findMany({
          select: {
            id: true,
            tenantId: true,
            unidadeId: true,
            tipo: true,
            config: true,
            segredoBusca: true,
          },
        });
        return todas;
      });
      for (const linha of linhas) {
        const conector = CONECTORES[linha.tipo];
        const config = linha.config;
        if (!conector || !config || typeof config !== 'object') continue;
        if (Array.isArray(config)) continue;
        // Sem `novos`: nada aqui chegou agora, então nada é recusado.
        const selada = selarConfig(
          conector,
          linha,
          config as Record<string, unknown>,
          linha.segredoBusca,
          new Set(),
          chave,
        );
        resumo.emClaro += selada.emClaro;
        if (
          selada.cifrados === 0 &&
          selada.segredoBusca === linha.segredoBusca
        ) {
          continue;
        }
        const r = await TenantContext.runAsSystem(async () => {
          const gravou = await this.prisma.integracao.updateMany({
            where: {
              id: linha.id,
              segredoBusca: linha.segredoBusca,
              config: { equals: config as Prisma.InputJsonValue },
            },
            data: {
              config: selada.config as Prisma.InputJsonValue,
              segredoBusca: selada.segredoBusca,
            },
          });
          return gravou;
        });
        if (r.count === 1) {
          resumo.gravadas += 1;
          resumo.cifrados += selada.cifrados;
        } else {
          resumo.adiadas += 1;
        }
      }
      if (resumo.gravadas || resumo.emClaro || resumo.adiadas) {
        this.logger.log(
          `Segredos das integrações: ${resumo.cifrados} cifrado(s) em ${resumo.gravadas} linha(s); ` +
            `${resumo.emClaro} ainda em claro; ${resumo.adiadas} linha(s) para a próxima subida.`,
        );
      }
    } catch (err) {
      this.logger.error(
        `Migração dos segredos das integrações falhou: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
    return resumo;
  }
}
