import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gogem_payment/payment.dart' show PixCharge, PointCharge;
import '../catalog/catalog_models.dart';

sealed class PublicadoResult {}

class MenuJaAtualizado extends PublicadoResult {
  MenuJaAtualizado(this.aparenciaJson);

  /// Aparência (por loja) — vem LIVE em toda resposta, mesmo sem catálogo novo.
  final Object? aparenciaJson;
}

class MenuAtualizado extends PublicadoResult {
  MenuAtualizado(this.body, this.snapshot, this.aparenciaJson);

  /// Corpo bruto (persistido como fonte da verdade local).
  final Map<String, dynamic> body;
  final MenuSnapshot snapshot;

  /// Aparência (por loja).
  final Object? aparenciaJson;
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
    final aparencia = body is Map ? body['aparencia'] : null;
    if (body is Map && body['atualizado'] == false) {
      return MenuJaAtualizado(aparencia);
    }
    if (body is Map<String, dynamic>) {
      return MenuAtualizado(body, MenuSnapshot.fromPublicadoJson(body), aparencia);
    }
    throw GogemApiException(200, 'corpo inesperado');
  }

  /// POST /dispositivos/heartbeat — telemetria (device-authed). Envia o estado
  /// atual do totem (papel, fila, versão). Silencioso: erros não quebram o app.
  Future<void> heartbeat(Map<String, dynamic> status) async {
    final uri = Uri.parse('$baseUrl/dispositivos/heartbeat');
    final res = await _client
        .post(uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode(status))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw GogemApiException(res.statusCode, res.body);
    }
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
              'Idempotency-Key': '${corpo['idempotencyKey']}',
            },
            body: jsonEncode(corpo))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// GET /kiosk/latest — manifesto da release mais nova (auto-update). Devolve
  /// null quando não há release publicada. O totem compara o versionCode.
  Future<KioskRelease?> latestRelease() async {
    final uri = Uri.parse('$baseUrl/kiosk/latest');
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw GogemApiException(res.statusCode, res.body);
    }
    final body = utf8.decode(res.bodyBytes).trim();
    if (body.isEmpty || body == 'null') return null;
    final b = jsonDecode(body);
    if (b is! Map || b['versionCode'] == null) return null;
    return KioskRelease.fromJson(b.cast<String, dynamic>());
  }

  /// POST /pagamentos/pix — cria a cobrança e devolve o QR (F8). Idempotente
  /// por orderId (uuid do pedido).
  Future<PixCharge> criarPix({
    required int amountCents,
    required String orderId,
    String? cpfCnpj,
    String? descricao,
  }) async {
    final uri = Uri.parse('$baseUrl/pagamentos/pix');
    final res = await _client
        .post(uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'amountCents': amountCents,
              'orderId': orderId,
              if (cpfCnpj != null) 'cpfCnpj': cpfCnpj,
              if (descricao != null) 'descricao': descricao,
            }))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw GogemApiException(res.statusCode, res.body);
    }
    return _pixDe(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// GET /pagamentos/pix/:id — status atual da cobrança (polling).
  Future<PixCharge> pixStatus(String id) async {
    final uri = Uri.parse('$baseUrl/pagamentos/pix/$id');
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw GogemApiException(res.statusCode, res.body);
    }
    return _pixDe(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  PixCharge _pixDe(dynamic b) {
    final m = (b as Map).cast<String, dynamic>();
    final exp = m['expiresAt'];
    return PixCharge(
      id: '${m['id']}',
      status: '${m['status']}',
      amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
      copiaECola: m['copiaECola'] as String?,
      qrImage: m['qrImage'] as String?,
      expiresAt: exp is String ? DateTime.tryParse(exp) : null,
    );
  }

  /// POST /pagamentos/point — cria a cobrança de cartão na maquininha Point.
  Future<PointCharge> criarPoint({
    required int amountCents,
    required String orderId,
    String? tipo,
  }) async {
    final uri = Uri.parse('$baseUrl/pagamentos/point');
    final res = await _client
        .post(uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'amountCents': amountCents,
              'orderId': orderId,
              if (tipo != null) 'tipo': tipo,
            }))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw GogemApiException(res.statusCode, res.body);
    }
    return _pointDe(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// GET /pagamentos/point/:id — status da cobrança (polling).
  Future<PointCharge> pointStatus(String id) async {
    final uri = Uri.parse('$baseUrl/pagamentos/point/$id');
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw GogemApiException(res.statusCode, res.body);
    }
    return _pointDe(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// POST /pagamentos/point/:id/cancelar — cancela a cobrança (a maquininha para).
  Future<void> pointCancelar(String id) async {
    final uri = Uri.parse('$baseUrl/pagamentos/point/$id/cancelar');
    await _client
        .post(uri, headers: {..._headers, 'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 12));
  }

  /// GET /pagamentos/status/:orderId — status consolidado (Point ou PIX) por
  /// uuid do pedido. Usado na recuperação no boot (F10): o totem pergunta "esse
  /// pedido que ficou preso — foi pago?". Devolve `{tipo, status}`; tipo pode ser
  /// 'point' | 'pix' | 'nenhum'.
  Future<({String tipo, String status})> statusPorOrder(String orderId) async {
    final uri = Uri.parse('$baseUrl/pagamentos/status/$orderId');
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw GogemApiException(res.statusCode, res.body);
    }
    final m = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
        .cast<String, dynamic>();
    return (tipo: '${m['tipo']}', status: '${m['status']}');
  }

  PointCharge _pointDe(dynamic b) {
    final m = (b as Map).cast<String, dynamic>();
    return PointCharge(
      id: '${m['id']}',
      status: '${m['status']}',
      amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
      tipo: m['tipo'] as String?,
    );
  }
}

/// Manifesto de uma release do APK do totem (auto-update).
class KioskRelease {
  const KioskRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    this.notas,
    this.obrigatorio = false,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final String? notas;
  final bool obrigatorio;

  factory KioskRelease.fromJson(Map<String, dynamic> j) => KioskRelease(
        versionCode: (j['versionCode'] as num).toInt(),
        versionName: '${j['versionName'] ?? ''}',
        apkUrl: '${j['apkUrl'] ?? ''}',
        sha256: '${j['sha256'] ?? ''}',
        notas: j['notas'] as String?,
        obrigatorio: j['obrigatorio'] == true,
      );
}
