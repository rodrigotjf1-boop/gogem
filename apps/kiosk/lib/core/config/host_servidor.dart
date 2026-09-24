import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/catalog/catalog_sync.dart' show databaseProvider;

/// G1/K1 — ENDEREÇO do servidor com quem este totem conversa.
///
/// Até aqui o host era decidido no build (`--dart-define=GOGEM_API_URL`), então apontar
/// um aparelho para o servidor da loja exigia um APK por loja. Agora ele chega no
/// PAREAMENTO e fica guardado aqui: `null` = nuvem (o host do build), preenchido = o
/// servidor da loja.
///
/// Guardado no `kv` do SQLite, do mesmo jeito que o token do dispositivo — o totem
/// reinicia (ou fica sem energia) e continua falando com quem deve.
const kvChaveHost = 'api_base';
const kvChaveCa = 'ca_pem';

/// Destino deste totem: para onde falar e em quem confiar.
class DestinoServidor {
  const DestinoServidor({this.apiBase, this.caPem});
  final String? apiBase;

  /// Certificado PÚBLICO da autoridade do servidor da loja (K2). O servidor serve HTTPS
  /// com certificado próprio, gerado por instalação; sem esta CA o Android recusa a
  /// conexão. Nulo = nuvem (certificado público, confiado pelo sistema).
  final String? caPem;

  bool get temServidor => (apiBase ?? '').isNotEmpty;
}

class HostServidorNotifier extends Notifier<DestinoServidor> {
  @override
  DestinoServidor build() => const DestinoServidor();

  /// Lê o endereço salvo (boot). Sem valor = nuvem, o padrão de quem não tem servidor.
  Future<void> carregar() async {
    final db = await ref.read(databaseProvider.future);
    final host = await _ler(db, kvChaveHost);
    state = DestinoServidor(
      apiBase: host,
      caPem: host == null ? null : await _ler(db, kvChaveCa),
    );
  }

  Future<String?> _ler(Database db, String chave) async {
    final r = await db.query('kv', where: 'chave = ?', whereArgs: [chave]);
    final v = r.isNotEmpty ? r.first['valor'] as String? : null;
    return (v != null && v.isNotEmpty) ? v : null;
  }

  /// Guarda o destino recebido no pareamento (ou limpa, voltando para a nuvem).
  /// Sem endereço não há em quem confiar: limpar o endereço limpa o certificado junto.
  Future<void> definir(String? apiBase, {String? caPem}) async {
    final host = (apiBase ?? '').trim();
    final ca = (caPem ?? '').trim();
    final db = await ref.read(databaseProvider.future);
    if (host.isEmpty) {
      await db.delete('kv', where: 'chave = ?', whereArgs: [kvChaveHost]);
      await db.delete('kv', where: 'chave = ?', whereArgs: [kvChaveCa]);
      state = const DestinoServidor();
      return;
    }
    await db.insert('kv', {'chave': kvChaveHost, 'valor': host},
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (ca.isEmpty) {
      await db.delete('kv', where: 'chave = ?', whereArgs: [kvChaveCa]);
    } else {
      await db.insert('kv', {'chave': kvChaveCa, 'valor': ca},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    state = DestinoServidor(apiBase: host, caPem: ca.isEmpty ? null : ca);
  }
}

final hostServidorProvider =
    NotifierProvider<HostServidorNotifier, DestinoServidor>(
        HostServidorNotifier.new);
