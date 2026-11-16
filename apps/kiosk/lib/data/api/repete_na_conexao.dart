import 'dart:io';
import 'package:http/http.dart' as http;

/// Repete UMA vez o pedido que nem chegou a abrir conexão (ERR-044).
///
/// No totem (Tinker Board, Android 11) a PRIMEIRA chamada do app à nuvem depois de
/// abrir às vezes falha com "No route to host" (errno 113), e a seguinte, milissegundos
/// depois, passa: o atualizador falhava sempre ao abrir e o primeiro PIX mostrava erro
/// até o cliente tocar "Tentar novamente". Repetir é seguro mesmo num POST — o erro é
/// de CONEXÃO, nada chegou ao servidor. Erro depois de conectar (resposta cortada,
/// conexão derrubada) NÃO repete: aí o servidor pode ter recebido.
class ClienteQueRepeteNaConexao extends http.BaseClient {
  ClienteQueRepeteNaConexao(
    this._interno, {
    this.espera = const Duration(milliseconds: 400),
  });

  final http.Client _interno;
  final Duration espera;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // A cópia sai ANTES do envio: o pedido enviado fica finalizado.
    final copia = request is http.Request ? _copiar(request) : null;
    try {
      return await _interno.send(request);
    } catch (e) {
      if (copia == null || !falhaAoConectar(e)) rethrow;
      await Future<void>.delayed(espera);
      return _interno.send(copia);
    }
  }

  @override
  void close() => _interno.close();
}

http.Request _copiar(http.Request r) {
  final c = http.Request(r.method, r.url)
    ..followRedirects = r.followRedirects
    ..maxRedirects = r.maxRedirects
    ..persistentConnection = r.persistentConnection;
  c.headers.addAll(r.headers);
  c.bodyBytes = r.bodyBytes;
  return c;
}

/// Erro de conexão que NÃO chegou a abrir (errno do Linux/Android): 101 rede
/// inacessível, 111 conexão recusada, 113 sem rota até o servidor.
bool falhaAoConectar(Object e) {
  if (e is SocketException) {
    final codigo = e.osError?.errorCode;
    if (codigo == 101 || codigo == 111 || codigo == 113) return true;
  }
  final m = e.toString();
  return m.contains('No route to host') ||
      m.contains('Network is unreachable') ||
      m.contains('Connection refused');
}
