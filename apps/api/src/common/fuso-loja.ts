/**
 * Datas de NEGÓCIO no fuso da loja (ERR-014).
 *
 * A API e o banco rodam em UTC (imagens oficiais; `show timezone` = `Etc/UTC` no gogem-db).
 * "Hoje", "mês" e a data que o painel manda têm de ser lidos no fuso de onde a loja opera —
 * calculados no fuso do servidor, o dia virava às 21h de Brasília: a venda do jantar caía no
 * dia seguinte e o card "Hoje" zerava às 21h.
 *
 * O fuso vem do banco de fusos (Intl), nunca de um "-3" fixo: o país já teve horário de verão
 * e pode voltar a ter.
 */
export const FUSO_LOJA = 'America/Sao_Paulo';

/** Data e hora "de parede" (o que o relógio da loja mostra). `mes` de 1 a 12. */
export interface Parede {
  ano: number;
  mes: number;
  dia: number;
  hora: number;
  minuto: number;
  segundo: number;
  ms: number;
}

const formatadores = new Map<string, Intl.DateTimeFormat>();
function formatador(fuso: string): Intl.DateTimeFormat {
  let f = formatadores.get(fuso);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: fuso,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    });
    formatadores.set(fuso, f);
  }
  return f;
}

/** O que o relógio da loja mostra num instante. */
export function paredeEm(instante: Date, fuso = FUSO_LOJA): Parede {
  const partes: Record<string, number> = {};
  for (const p of formatador(fuso).formatToParts(instante)) {
    if (p.type !== 'literal') partes[p.type] = Number(p.value);
  }
  return {
    ano: partes.year,
    mes: partes.month,
    dia: partes.day,
    hora: partes.hour % 24,
    minuto: partes.minute,
    segundo: partes.second,
    ms: instante.getUTCMilliseconds(),
  };
}

/** Quanto o relógio da loja está à frente do UTC num instante (ms; Brasília = -3 h). */
function deslocamentoMs(instante: Date, fuso: string): number {
  const p = paredeEm(instante, fuso);
  const comoUtc = Date.UTC(
    p.ano,
    p.mes - 1,
    p.dia,
    p.hora,
    p.minuto,
    p.segundo,
    p.ms,
  );
  return comoUtc - instante.getTime();
}

/** O instante em que o relógio da loja mostra esta data e hora. */
export function instanteDaParede(p: Parede, fuso = FUSO_LOJA): Date {
  const chute = Date.UTC(
    p.ano,
    p.mes - 1,
    p.dia,
    p.hora,
    p.minuto,
    p.segundo,
    p.ms,
  );
  // Duas passadas: a segunda acerta a hora que cai perto de uma mudança de fuso.
  const t1 = chute - deslocamentoMs(new Date(chute), fuso);
  return new Date(chute - deslocamentoMs(new Date(t1), fuso));
}

const TEXTO_PAREDE =
  /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?)?$/;

function lerParede(
  texto: string,
): { parede: Parede; soData: boolean; temMs: boolean } | null {
  const m = TEXTO_PAREDE.exec(texto.trim());
  if (!m) return null;
  return {
    parede: {
      ano: Number(m[1]),
      mes: Number(m[2]),
      dia: Number(m[3]),
      hora: Number(m[4] ?? 0),
      minuto: Number(m[5] ?? 0),
      segundo: Number(m[6] ?? 0),
      ms: m[7] ? Number(m[7].padEnd(3, '0')) : 0,
    },
    soData: m[4] === undefined,
    temMs: m[7] !== undefined,
  };
}

/**
 * Início de um período vindo do painel. `YYYY-MM-DD` ou data e hora SEM fuso = hora da loja;
 * com `Z` ou `±hh:mm`, vale o instante que o texto diz.
 */
export function inicioDaLoja(texto: string, fuso = FUSO_LOJA): Date {
  const l = lerParede(texto);
  return l ? instanteDaParede(l.parede, fuso) : new Date(texto);
}

/**
 * Fim INCLUSIVO de um período vindo do painel: `YYYY-MM-DD` = último milissegundo desse dia na
 * loja; hora sem milissegundos (`T23:59:59`) = até o fim daquele segundo. Com fuso, vale o
 * instante do texto.
 */
export function fimDaLoja(texto: string, fuso = FUSO_LOJA): Date {
  const l = lerParede(texto);
  if (!l) return new Date(texto);
  if (l.soData) {
    const seguinte = inicioDoDia(instanteDaParede(l.parede, fuso), fuso, 1);
    return new Date(seguinte.getTime() - 1);
  }
  const t = instanteDaParede(l.parede, fuso);
  return l.temMs ? t : new Date(t.getTime() + 999);
}

/** Meia-noite (na loja) do dia de `agora`, deslocada `dias` dias. */
export function inicioDoDia(agora: Date, fuso = FUSO_LOJA, dias = 0): Date {
  const p = paredeEm(agora, fuso);
  const d = new Date(Date.UTC(p.ano, p.mes - 1, p.dia + dias));
  return instanteDaParede(
    {
      ano: d.getUTCFullYear(),
      mes: d.getUTCMonth() + 1,
      dia: d.getUTCDate(),
      hora: 0,
      minuto: 0,
      segundo: 0,
      ms: 0,
    },
    fuso,
  );
}

/** Dia 1, meia-noite (na loja), do mês de `agora`, deslocado `meses` meses. */
export function inicioDoMes(agora: Date, fuso = FUSO_LOJA, meses = 0): Date {
  const p = paredeEm(agora, fuso);
  const d = new Date(Date.UTC(p.ano, p.mes - 1 + meses, 1));
  return instanteDaParede(
    {
      ano: d.getUTCFullYear(),
      mes: d.getUTCMonth() + 1,
      dia: 1,
      hora: 0,
      minuto: 0,
      segundo: 0,
      ms: 0,
    },
    fuso,
  );
}
