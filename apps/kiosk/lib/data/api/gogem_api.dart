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

/// Cliente HTTP do GoGeM. Auth temporária por JWT de dev (AppConfig) até o
/// pareamento de dispositivo (§7.1) existir — trocar então por token de device.
class GogemApi {
  GogemApi({required this.baseUrl, required this.bearer, http.Client? client})
      : _client = client ?? http.Client();
  final String baseUrl;
  final String bearer;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (bearer.isNotEmpty) 'Authorization': 'Bearer $bearer',
      };

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
}
