import 'dart:io' show HttpDate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/catalog/catalog_sync.dart' show databaseProvider;

/// K3 — a hora do totem vem do SERVIDOR, não do aparelho.
///
/// O totem usa a hora para coisas que a loja enxerga: o horário no cupom e, mais
/// sensível, o DIA que zera a senha sequencial. Um Android de sala fica sem internet e
/// deriva; depois de uma queda de energia pode voltar com data errada — e aí a senha
/// reinicia fora de hora, com dois clientes carregando o mesmo número.
///
/// Mecanismo: toda resposta HTTP traz o cabeçalho `Date`. Guardamos a DIFERENÇA entre
/// ele e o relógio local e aplicamos daí em diante. Não mexe no relógio do sistema (o
/// app não tem permissão para isso) — corrige só a hora que o totem usa.
///
/// O desvio fica no `kv`: depois de um reinício sem rede, o totem continua com a última
/// correção conhecida em vez de voltar ao relógio torto do aparelho.
///
/// Devolve SEMPRE hora LOCAL: o "dia" da senha é o dia da loja. Converter para UTC aqui
/// mudaria a virada do contador de lugar (ver LIC-006 no registro geral).
const kvChaveDesvio = 'relogio_desvio_ms';

/// Abaixo disto o cabeçalho é ignorado: `Date` tem precisão de segundos e a rede atrasa,
/// então desvio de poucos segundos é ruído, não correção.
const desvioMinimo = Duration(seconds: 5);

class RelogioServidorNotifier extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  /// Lê o desvio guardado (boot).
  Future<void> carregar() async {
    final db = await ref.read(databaseProvider.future);
    final r = await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveDesvio]);
    final ms = int.tryParse((r.isNotEmpty ? r.first['valor'] as String? : null) ?? '');
    if (ms != null) state = Duration(milliseconds: ms);
  }

  /// Registra a hora que veio do servidor (cabeçalho `Date` de qualquer resposta).
  /// Cabeçalho ausente ou ilegível não muda nada — servidor sem `Date` não pode
  /// desregular o totem.
  Future<void> sincronizar(String? cabecalhoDate) async {
    final doServidor = parseDataHttp(cabecalhoDate);
    if (doServidor == null) return;
    final desvio = doServidor.difference(DateTime.now());
    if (desvio.abs() < desvioMinimo) return;
    state = desvio;
    final db = await ref.read(databaseProvider.future);
    await db.insert(
        'kv', {'chave': kvChaveDesvio, 'valor': desvio.inMilliseconds.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Hora corrente corrigida — LOCAL, como a loja enxerga.
  DateTime agora() => DateTime.now().add(state);
}

/// `Date` de HTTP (RFC 7231, sempre GMT) → DateTime LOCAL. `null` quando ausente ou
/// ilegível.
DateTime? parseDataHttp(String? valor) {
  final texto = (valor ?? '').trim();
  if (texto.isEmpty) return null;
  try {
    return HttpDate.parse(texto).toLocal();
  } catch (_) {
    return null;
  }
}

final relogioServidorProvider =
    NotifierProvider<RelogioServidorNotifier, Duration>(
        RelogioServidorNotifier.new);
