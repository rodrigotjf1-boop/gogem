import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantContext } from '../../tenant/tenant-context';
import { CatalogoPublicacaoService } from '../../catalogo/catalogo-publicacao.service';
import { RegemImportService } from './regem-import.service';

const INTERVALO_PADRAO_MIN = 5;
const ATRASO_INICIAL_MS = 30_000;

/**
 * Sincronização periódica Regem→GoGeM (o Regem como "segundo admin"): a cada
 * intervalo, para cada tenant com a integração Regem ativa, puxa o catálogo do
 * Regem e reflete nos produtos JÁ LINKADOS (preço, nome, descrição, pausa) sem
 * ninguém abrir o admin do GoGeM. Republica só quando algo muda.
 *
 * Sem `@nestjs/schedule`: setInterval simples. Desligado em teste
 * (NODE_ENV=test) e quando `REGEM_SYNC_INTERVAL_MIN <= 0`.
 */
@Injectable()
export class RegemSyncPoller implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RegemSyncPoller.name);
  private timer?: ReturnType<typeof setInterval>;
  private rodando = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly imports: RegemImportService,
    private readonly publicacao: CatalogoPublicacaoService,
  ) {}

  onModuleInit(): void {
    const min = Number(
      this.config.get<string>('REGEM_SYNC_INTERVAL_MIN') ??
        INTERVALO_PADRAO_MIN,
    );
    if (!Number.isFinite(min) || min <= 0 || process.env.NODE_ENV === 'test') {
      return;
    }
    const ms = min * 60_000;
    this.timer = setInterval(() => void this.tick(), ms);
    // Uma passada logo após o boot assentar (não trava o startup).
    setTimeout(() => void this.tick(), ATRASO_INICIAL_MS).unref?.();
    this.logger.log(`Sync Regem→GoGeM ligado (a cada ${min} min).`);
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /**
   * Uma passada: por tenant com Regem ativo, sincroniza os linkados e republica
   * se mudou. Best-effort — a falha de um tenant não derruba os outros.
   */
  async tick(): Promise<void> {
    if (this.rodando) return; // evita sobreposição de execuções
    this.rodando = true;
    try {
      const integracoes = await TenantContext.runAsSystem(() =>
        this.prisma.integracao.findMany({
          where: { tipo: 'regem', ativo: true },
          select: { tenantId: true },
        }),
      );
      for (const { tenantId } of integracoes) {
        await TenantContext.run({ tenantId }, async () => {
          try {
            const { alterados } = await this.imports.sincronizarLinkados();
            if (alterados > 0) {
              await this.publicacao.publicar(null);
              this.logger.log(
                `Regem→GoGeM: ${alterados} produto(s) sincronizado(s) (tenant ${tenantId}).`,
              );
            }
          } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            this.logger.warn(`Sync Regem falhou (tenant ${tenantId}): ${msg}`);
          }
        });
      }
    } finally {
      this.rodando = false;
    }
  }
}
