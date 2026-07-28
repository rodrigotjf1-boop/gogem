import 'dart:convert';
import 'package:http/http.dart' as http;
import '../catalog/catalog_models.dart';

sealed class PublicadoResult {}

class MenuJaAtualizado extends PublicadoResult {}

class MenuAtualizado extends PublicadoResult {
  MenuAtualizado(this.body, this.snapshot);
  /// Corpo bruto (persistido como fonte da verdade local).
  final Map<String, dynamic> body;
  final MenuSnapshot snapshot;
}

class GogemApiException implements Exception {
  GogemApiException(this.status, this.mensagem);
  final int status;
  final String mensagem;
  @override
  String toString() => 'GogemApiException($status): $mensagem';
}

/// Cliente HTTP do GoGeM.
///
/// Auth: quando o totem está pareado, envia `X-Device-Token` (token de
/// dispositivo, NÃO expira). Sem pareamento, cai no `Bearer <devJwt>` do
/// AppConfig (ponte de dev/staging). O backend aceita os dois (JwtOrDeviceGuard).
class GogemApi {
  GogemApi({
    required this.baseUrl,
    required this.bearer,
    this.deviceToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final String bearer;

  /// Token de dispositivo (pareamento). Preferido sobre o JWT quando presente.
  final String? deviceToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (deviceToken != null && deviceToken!.isNotEmpty)
          'X-Device-Token': deviceToken!
        else if (bearer.isNotEmpty)
          'Authorization': 'Bearer $bearer',
      };

  /// POST /publico/dispositivos/parear — troca o código de 6 dígitos por um
  /// token de dispositivo (endpoint público, sem auth). Retorna o token.
  Future<String> parear(String codigo) async {
    final uri = Uri.parse('$baseUrl/publico/dispositivos/parear');
    final res = await _client
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'codigo': codigo}))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      final token = (b is Map ? b['token'] : null) as String?;
      if (token != null && token.isNotEmpty) return token;
      throw GogemApiException(200, 'resposta de pareamento sem token');
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// GET /catalogo/publicado?desde=<versao>
  /// `desde >= versão atual` → `{atualizado:false}` (checagem barata).
  Future<PublicadoResult> getCatalogoPublicado({int? desde}) async {
    final uri = Uri.parse('$baseUrl/catalogo/publicado').replace(
      queryParameters: {if (desde != null) 'desde': '$desde'},
    );
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw GogemApiException(res.statusCode, res.body);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && body['atualizado'] == false) return MenuJaAtualizado();
    if (body is Map<String, dynamic>) {
      return MenuAtualizado(body, MenuSnapshot.fromPublicadoJson(body));
    }
    throw GogemApiException(200, 'corpo inesperado');
  }

  /// POST /vendas — lançamento idempotente do pedido pago (F6).
  /// `Idempotency-Key` = uuid do pedido: reenvio JAMAIS duplica; o backend
  /// responde 200/201 (ou 409 já-processado, tratado como sucesso pelo sync).
  Future<Map<String, dynamic>> enviarVenda(Map<String, dynamic> corpo) async {
    final uri = Uri.parse('$baseUrl/vendas');
    final res = await _client
        .post(uri,
            headers: {
              ..._headers,
              'Content-Type': 'application/json',
              'Idempotency-Key': '${corpo['uuid']}',
            },
            body: jsonEncode(corpo))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }
}
