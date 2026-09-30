import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { describe, expect, it } from 'vitest';
import { UpdateAparenciaDto } from '../src/aparencia/dto/update-aparencia.dto';

/**
 * Estilo do totem (docs/templates/00 §3.7). Os 5 templates novos entram; o "Padrão GoGeM"
 * saiu da lista (as lojas nele foram para o GoGen na migration 20260930000000).
 */
async function erros(temaPreset: string) {
  return validate(plainToInstance(UpdateAparenciaDto, { temaPreset }));
}

describe('UpdateAparenciaDto — temaPreset', () => {
  it.each(['brasa2', 'vitrine', 'estudio', 'neon', 'diner'])(
    'aceita o template novo %s',
    async (chave) => {
      expect(await erros(chave)).toHaveLength(0);
    },
  );

  it.each(['brasa', 'gogen'])('continua aceitando %s', async (chave) => {
    expect(await erros(chave)).toHaveLength(0);
  });

  it('aceita burger até a migração das lojas para o Brasa 2.0', async () => {
    expect(await erros('burger')).toHaveLength(0);
  });

  it.each(['padrao', 'carrossel', 'BRASA2', ''])('recusa %j', async (chave) => {
    const e = await erros(chave);
    expect(e).toHaveLength(1);
    expect(e[0].property).toBe('temaPreset');
  });
});
