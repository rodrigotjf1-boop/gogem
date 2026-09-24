import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// K2 — cliente HTTP que confia na autoridade do SERVIDOR da loja.
///
/// O servidor local serve HTTPS com certificado próprio, gerado por instalação
/// (`edge/gen-cert.mjs`), cujo SAN cobre o IP da LAN, `regem.local` e `localhost`. O
/// Android não conhece essa autoridade: sem confiar nela, toda chamada ao servidor morre
/// no handshake. A CA chega no pareamento (é certificado PÚBLICO, nunca a chave).
///
/// `withTrustedRoots: true` MANTÉM as autoridades públicas: o mesmo aplicativo continua
/// falando com a nuvem (e baixando imagem de onde for) sem virar refém do certificado
/// da loja.
http.Client clienteParaServidor(String? caPem, {void Function(String? date)? aoResponder}) {
  final ctx = contextoComCa(caPem);
  final base = ctx == null ? http.Client() : IOClient(HttpClient(context: ctx));
  return aoResponder == null ? base : _ClienteObservado(base, aoResponder);
}

/// K3 — observa o cabeçalho `Date` de TODA resposta, num lugar só.
///
/// Fica no cliente, e não em cada chamada, porque assim catálogo, venda, pagamento e
/// heartbeat alimentam o relógio sem ninguém precisar lembrar. O observador NUNCA pode
/// derrubar a requisição: erro dele é engolido — hora errada é problema menor que venda
/// que não sai.
class _ClienteObservado extends http.BaseClient {
  _ClienteObservado(this._interno, this._aoResponder);
  final http.Client _interno;
  final void Function(String? date) _aoResponder;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = await _interno.send(request);
    try {
      _aoResponder(r.headers['date']);
    } catch (_) {
      /* relógio é acessório: nunca atrapalha a chamada */
    }
    return r;
  }

  @override
  void close() => _interno.close();
}

/// Monta o contexto TLS que confia na CA informada. Devolve `null` quando não há
/// certificado ou quando ele é ilegível — separado para o ramo ser observável em teste
/// (o cliente padrão do Dart já é um `IOClient`, então o tipo não distingue nada).
///
/// Certificado ilegível NÃO pode tirar o totem do ar: vira `null`, o app segue com o
/// cliente padrão e a chamada ao servidor falha como erro de conexão — visível — em vez
/// de o aplicativo não abrir.
SecurityContext? contextoComCa(String? caPem) {
  final pem = (caPem ?? '').trim();
  if (pem.isEmpty) return null;
  try {
    final ctx = SecurityContext(withTrustedRoots: true);
    ctx.setTrustedCertificatesBytes(utf8.encode(pem));
    return ctx;
  } catch (_) {
    return null;
  }
}
