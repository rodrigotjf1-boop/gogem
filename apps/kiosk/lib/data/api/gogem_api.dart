import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gogem_payment/payment.dart' show PixCharge, PointCharge;
import '../catalog/catalog_models.dart';

sealed class PublicadoResult {}

class MenuJaAtualizado extends PublicadoResult {
  MenuJaAtualizado(this.aparenciaJson, {this.fiscalJson, this.disponibilidadeJson});

  /// Aparência (por loja) — vem LIVE em toda resposta, mesmo sem catálogo novo.
  final Object? aparenciaJson;

  /// Fiscal da loja (servidor local) — também LIVE: ligar a NFC-e não muda o cardápio.
  final Object? fiscalJson;

  /// O que está pausado AGORA no painel (nuvem) — LIVE, por cima do retrato publicado.
  final Object? disponibilidadeJson;
}

class MenuAtualizado extends PublicadoResult {
  MenuAtualizado(this.body, this.snapshot, this.aparenciaJson,
      {this.fiscalJson, this.disponibilidadeJson});

  /// Corpo bruto (persistido como fonte da verdade local).
  final Map<String, dynamic> body;
  final MenuSnapshot snapshot;

  /// Aparência (por loja).
  final Object? aparenciaJson;

  /// Fiscal da loja (servidor local).
  final Object? fiscalJson;

  /// Disponibilidade ao vivo (nuvem).
  final Object? disponibilidadeJson;
}

class GogemApiException implements Exception {
  GogemApiException(this.status, this.mensagem);
  final int status;
  final String mensagem;

  /// A mensagem do servidor, limpa (o `message` do corpo JSON), para mostrar e registrar.
  String get motivo {
    try {
      final b = jsonDecode(mensagem);
      final m = b is Map ? b['message'] : null;
      if (m is List) return m.join('; ');
      if (m is String && m.trim().isNotEmpty) return m.trim();
    } catch (_) {/* corpo não é JSON */}
    final t = mensagem.trim();
    return t.length > 200 ? t.substring(0, 200) : t;
  }

  @override
  String toString() => 'GogemApiException($status): $mensagem';
}

/// Recusa DEFINITIVA da venda (400/422): reenviar a mesma venda dá o mesmo resultado. O
/// resto (rede, tempo esgotado, 5xx, 401/403/404/408/429) é passageiro e se reenvia.
bool recusaDefinitiva(int status) => status == 400 || status == 422;

/// Quanto o totem espera a venda (ou a liberação do pedido retido). Com NFC-e o Regem só
/// responde depois da nota: ~12 s no pior caso da primeira vez, até 25 s quando a repetição
/// espera uma emissão em andamento. 45 s é o combinado com o Regem (#574).
const prazoVendaTotem = Duration(seconds: 45);

/// Cliente HTTP do GoGeM.
///
/// Auth: quando o totem está pareado, envia `X-Device-Token` (token de
/// dispositivo, NÃO expira). Sem pareamento, cai no `Bearer <devJwt>` do
/// AppConfig (ponte de dev/staging). O backend aceita os dois (JwtOrDeviceGuard).
/// Resposta do pareamento: a credencial e o DESTINO deste totem.
class PareamentoResultado {
  const PareamentoResultado({required this.token, this.apiBase, this.caPem});
  final String token;

  /// Endereço do servidor da loja. `null` = nuvem (padrão de quem não tem servidor).
  final String? apiBase;

  /// Certificado PÚBLICO da autoridade do servidor da loja (K2). Sem ele o Android
  /// recusa o HTTPS do servidor local, que usa certificado próprio.
  final String? caPem;
}

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
  /// token de dispositivo (endpoint público, sem auth).
  ///
  /// Devolve também o DESTINO deste totem (`apiBase`): preenchido = fala com o servidor
  /// da loja; nulo/ausente = nuvem. Assim o mesmo APK atende loja com e sem servidor
  /// local — antes o destino vivia no build e trocá-lo exigia reinstalar o aplicativo.
  Future<PareamentoResultado> parear(String codigo) async {
    final uri = Uri.parse('$baseUrl/publico/dispositivos/parear');
    final res = await _client
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'codigo': codigo}))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      final token = (b is Map ? b['token'] : null) as String?;
      if (token != null && token.isNotEmpty) {
        final base = (b is Map ? b['apiBase'] : null)?.toString().trim();
        final ca = (b is Map ? b['caPem'] : null)?.toString().trim();
        return PareamentoResultado(
          token: token,
          apiBase: (base == null || base.isEmpty) ? null : base,
          caPem: (ca == null || ca.isEmpty) ? null : ca,
        );
      }
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
    final fiscal = body is Map ? body['fiscal'] : null;
    final disponibilidade = body is Map ? body['disponibilidade'] : null;
    if (body is Map && body['atualizado'] == false) {
      return MenuJaAtualizado(aparencia,
          fiscalJson: fiscal, disponibilidadeJson: disponibilidade);
    }
    if (body is Map<String, dynamic>) {
      return MenuAtualizado(body, MenuSnapshot.fromPublicadoJson(body), aparencia,
          fiscalJson: fiscal, disponibilidadeJson: disponibilidade);
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

  /// POST /telemetria/evento — sobe um evento/erro do totem (device-authed).
  /// Best-effort: sem token de dispositivo, nem tenta (nada a reportar antes do
  /// pareamento). Silencioso — erros aqui NUNCA propagam (não derruba o app).
  Future<void> reportarErro({
    required String mensagem,
    String? detalhe,
    String nivel = 'erro',
    String? appVersao,
  }) async {
    if (deviceToken == null || deviceToken!.isEmpty) return;
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/telemetria/evento'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'nivel': nivel,
              'mensagem': mensagem,
              if (detalhe != null) 'detalhe': detalhe,
              if (appVersao != null) 'appVersao': appVersao,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // telemetria é best-effort; nunca propaga.
    }
  }

  /// POST /vendas — lançamento idempotente do pedido pago (F6).
  /// `Idempotency-Key` = uuid do pedido: reenvio JAMAIS duplica; o backend
  /// responde 200/201 (ou 409 já-processado, tratado como sucesso pelo sync).
  Future<Map<String, dynamic>> enviarVenda(Map<String, dynamic> corpo,
      {Duration timeout = prazoVendaTotem}) async {
    final uri = Uri.parse('$baseUrl/vendas');
    final res = await _client
        .post(uri,
            headers: {
              ..._headers,
              'Content-Type': 'application/json',
              'Idempotency-Key': '${corpo['idempotencyKey']}',
            },
            body: jsonEncode(corpo))
        .timeout(timeout);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// K4 — POST /vendas/retido: registra o pedido no servidor da loja ANTES de cobrar.
  /// Devolve `{pedidoId, senha, total}`. A senha é a do BALCÃO e é ela que vai no cupom
  /// — o cliente sai com o mesmo número que a cozinha vai chamar.
  ///
  /// Só existe no modo servidor. Na nuvem o fluxo segue como sempre (paga e então lança).
  Future<Map<String, dynamic>> abrirPedidoRetido(Map<String, dynamic> corpo) async {
    final res = await _client
        .post(Uri.parse('$baseUrl/vendas/retido'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode(corpo))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// K4 — POST /vendas/:id/liberar: pagamento aprovado, o retido vira venda (comanda,
  /// caixa, produção). Reenvio não duplica: o servidor é idempotente pela chave do totem —
  /// e a repetição devolve a MESMA nota, com o DANFE remontado (é assim que se reimprime).
  Future<Map<String, dynamic>> liberarPedidoRetido(
      String pedidoId, List<dynamic> pagamentos,
      {Duration timeout = prazoVendaTotem}) async {
    final res = await _client
        .post(Uri.parse('$baseUrl/vendas/$pedidoId/liberar'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'pagamentos': pagamentos}))
        .timeout(timeout);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// K4 — POST /vendas/:id/cancelar: o cliente desistiu (ou recusou tentar de novo).
  /// Fica registrado com o MOTIVO, nos dois lados. Best-effort: nunca propaga — a tela
  /// já está encerrando o pedido, e o servidor expira o retido sozinho em 5 min.
  Future<void> cancelarPedidoRetido(String pedidoId, String motivo) async {
    try {
      await _client
          .post(Uri.parse('$baseUrl/vendas/$pedidoId/cancelar'),
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: jsonEncode({'motivo': motivo}))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      /* o servidor expira o retido sozinho */
    }
  }

  /// POST /pagamentos/estorno — o pagamento foi APROVADO mas a venda não se concluiu (a
  /// NFC-e não foi emitida, a venda foi recusada, o cupom fiscal não imprimiu). A nuvem do
  /// GoGeM estorna pelo `orderId` (uuid do pedido) e registra o motivo no relatório; no
  /// servidor da loja a chamada chega pelo repasse do Regem. Idempotente.
  ///
  /// Devolve o `estorno` (`feito`, `meio`, `valorCentavos`, `mensagem`). LANÇA em falha —
  /// quem chama decide: sem rede, o estorno fica pendente e a fila tenta de novo.
  Future<Map<String, dynamic>> estornarPagamento({
    required String orderId,
    required String motivo,
    String? etapa,
    int? senha,
    List<dynamic>? itens,
  }) async {
    final res = await _client
        .post(Uri.parse('$baseUrl/pagamentos/estorno'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': orderId,
              'motivo': motivo.length > 500 ? motivo.substring(0, 500) : motivo,
              if (etapa != null) 'etapa': etapa,
              if (senha != null) 'senha': senha,
              if (itens != null && itens.isNotEmpty) 'itens': itens,
            }))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      final e = b is Map ? b['estorno'] : null;
      return e is Map ? e.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// POST /vendas/:id/falha-impressao — servidor da loja (Regem #574): o DANFE não saiu no
  /// papel. O Regem cancela a nota (ou agenda, se está em contingência), desfaz a venda e
  /// cancela o pedido. Devolve `{ok, notaCancelada, cancelamentoPendente}`. LANÇA em falha:
  /// sem essa confirmação a venda continua valendo e NÃO se estorna.
  Future<Map<String, dynamic>> falhaImpressao(
      String pedidoId, String motivo) async {
    final res = await _client
        .post(Uri.parse('$baseUrl/vendas/$pedidoId/falha-impressao'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'motivo': motivo}))
        // O cancelamento da nota vai à SEFAZ (evento 110111): leva o tempo dela.
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map<String, dynamic> ? b : <String, dynamic>{};
    }
    throw GogemApiException(res.statusCode, res.body);
  }

  /// POST /vendas/falha — reporta um pagamento que NÃO passou (erro/recusa/
  /// timeout/cancelamento) + o `motivo`. O backend relata ao Regem (cupom "não
  /// passou"). BEST-EFFORT: nunca propaga — o cliente já vê o erro na tela.
  Future<void> reportarFalha(Map<String, dynamic> corpo,
      {required String motivo}) async {
    if (deviceToken == null || deviceToken!.isEmpty) return;
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/vendas/falha'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({...corpo, 'motivo': motivo}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // best-effort; nunca propaga.
    }
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
