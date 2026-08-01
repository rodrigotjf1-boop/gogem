import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração injetada em build-time (dart-define) — nada de segredo no repo.
/// O PADRÃO já aponta para produção, então um `flutter build apk --release` sem
/// flag gera um APK funcional (não mais localhost do emulador). Para dev/emulador,
/// sobrescreva:
/// flutter run --dart-define=GOGEM_API_URL=http://10.0.2.2:3000/api/v1 \
///             --dart-define=GOGEM_DEV_JWT=<token de staging até o pareamento existir>
class AppConfig {
  const AppConfig({required this.apiUrl, required this.devJwt});
  final String apiUrl;

  /// Temporário (§7.1 do repasse): até o pareamento de dispositivo existir,
  /// o app usa um JWT de dev/staging. Será trocado por token de dispositivo.
  final String devJwt;

  bool get temAuth => devJwt.isNotEmpty;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return const AppConfig(
    apiUrl: String.fromEnvironment('GOGEM_API_URL', defaultValue: 'https://api.gogem.com.br/api/v1'),
    devJwt: String.fromEnvironment('GOGEM_DEV_JWT', defaultValue: ''),
  );
});
