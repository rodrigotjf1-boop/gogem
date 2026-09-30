import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hardware/hardware_profile.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import 'movimento.dart';

/// O movimento permitido agora: `animacoes` do painel × perfil de hardware.
final movimentoProvider = Provider<Movimento>((ref) {
  final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
  return Movimento.de(ap, ref.watch(hardwareCapsProvider));
});
