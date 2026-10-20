import { Injectable, Logger } from '@nestjs/common';
import { RegemConfigResolver, type RegemConfig } from './regem-config.resolver';
import { chamarRegem, mensagemDoRegem } from './chamada-regem';

/** Timeout da requisição de pausa ao Regem (ms). */
const FETCH_TIMEOUT_MS = 10_000;

/**
 * RegemPauseClient — propaga pausa/despausa de item ao Regem (Fase 4,
 * GoGeM→Regem) via `POST {base}/sync/produtos/pausa` (credencial em
 * `chamada-regem.ts`: token de integração ou `X-Sync-Token`). Casa por
 * `codigoPdv`; o Regem escreve o canal 'gogem' em `canais_pausados`.
 *
 * Best-effort: falha aqui NÃO deve derrubar a operação local do GoGeM (a pausa
 * local já foi aplicada); logamos e seguimos. Config por tenant via resolver.
 */
@Injectable()
export class RegemPauseClient {
  private readonly logger = new Logger(RegemPauseClient.name);

  constructor(private readonly resolver: RegemConfigResolver) {}

  /** Pausa/despausa no Regem por código PDV. Devolve true se propagou. */
  async pausar(codigoPdv: string, pausado: boolean): Promise<boolean> {
    let cfg: RegemConfig;
    try {
      cfg = await this.resolver.resolve();
    } catch {
      // Integração Regem não configurada → nada a propagar (só pausa local).
      return false;
    }

    try {
      const res = await chamarRegem(this.resolver, cfg, {
        caminho: '/sync/produtos/pausa',
        metodo: 'POST',
        corpo: { codigoPdv, pausado, canal: 'gogem' },
        prazoMs: FETCH_TIMEOUT_MS,
        rotulo: 'a pausa',
      });
      if (!res.ok) {
        const corpo = await res.text().catch(() => '');
        this.logger.warn(
          `Pausa no Regem respondeu ${res.status} (${codigoPdv}): ${mensagemDoRegem(corpo)}`,
        );
        return false;
      }
      return true;
    } catch (err) {
      const motivo = err instanceof Error ? err.message : String(err);
      this.logger.warn(
        `Falha ao propagar pausa ao Regem (${codigoPdv}): ${motivo}`,
      );
      return false;
    }
  }
}
