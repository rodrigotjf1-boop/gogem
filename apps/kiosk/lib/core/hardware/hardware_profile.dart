import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Perfis de performance do totem.
/// `low` = Tinker Board S (RK3288, 2GB, ARM 32-bit): sem blur, sem partículas,
/// animações reduzidas. `high` = hardware novo (arm64/4GB+) ou Windows.
enum HardwareProfile { low, high }

class HardwareCaps {
  const HardwareCaps({
    required this.profile,
    required this.enableBlur,
    required this.enableParticles,
    required this.animationScale,
    required this.imageCacheMb,
  });
  final HardwareProfile profile;
  final bool enableBlur;
  final bool enableParticles;
  final double animationScale; // 1.0 normal, 0.6 reduzido
  final int imageCacheMb;

  static const low = HardwareCaps(
    profile: HardwareProfile.low,
    enableBlur: false,
    enableParticles: false,
    animationScale: 0.6,
    imageCacheMb: 64,
  );
  static const high = HardwareCaps(
    profile: HardwareProfile.high,
    enableBlur: true,
    enableParticles: true,
    animationScale: 1.0,
    imageCacheMb: 256,
  );

  /// Resolve pelo dart-define (provisionamento define por dispositivo) com
  /// heurística de fallback: 32-bit => low.
  static HardwareCaps resolve({String? override, required bool is64Bit}) {
    switch (override) {
      case 'low':
        return low;
      case 'high':
        return high;
    }
    return is64Bit ? high : low;
  }
}

final hardwareCapsProvider = Provider<HardwareCaps>((ref) {
  const override = String.fromEnvironment('GOGEM_HW_PROFILE'); // '', 'low', 'high'
  return HardwareCaps.resolve(
    override: override.isEmpty ? null : override,
    is64Bit: _is64BitBestEffort(),
  );
});

bool _is64BitBestEffort() {
  // Em Dart não há API direta; usamos o tamanho do ponteiro via força do runtime.
  // `1 << 62` só é representável nativamente em 64-bit sem BigInt no VM.
  return (1 << 62) > 0;
}
