import { Injectable, Logger } from '@nestjs/common';
import { RegemConfigResolver } from './regem-config.resolver';

/** Timeout da requisição de pausa ao Regem (ms). */
const FETCH_TIMEOUT_MS = 10_000;

/**
 * RegemPauseClient — propaga pausa/despausa de item ao Regem (Fase 4,
 * GoGeM→Regem) via `POST {base}/sync/produtos/pausa` (X-Sync-Token). Casa por
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
    let base: string;
    let token: string;
    try {
      ({ base, token } = await this.resolver.resolve());
    } catch {
      // Integração Regem não configurada → nada a propagar (só pausa local).
      return false;
    }

    const url = `${base.replace(/\/$/, '')}/sync/produtos/pausa`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'X-Sync-Token': token,
          'X-Loja-Token': token,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ codigoPdv, pausado, canal: 'gogem' }),
        signal: controller.signal,
      });
      if (!res.ok) {
        const corpo = await res.text().catch(() => '');
        this.logger.warn(
          `Pausa no Regem respondeu ${res.status} (${codigoPdv}): ${corpo}`,
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
    } finally {
      clearTimeout(timer);
    }
  }
}
