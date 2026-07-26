import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/hardware/hardware_profile.dart';

void main() {
  group('HardwareCaps.resolve', () {
    test('override low vence heurística', () {
      final c = HardwareCaps.resolve(override: 'low', is64Bit: true);
      expect(c.profile, HardwareProfile.low);
      expect(c.enableBlur, isFalse);
      expect(c.enableParticles, isFalse);
      expect(c.animationScale, lessThan(1));
    });
    test('override high vence heurística', () {
      final c = HardwareCaps.resolve(override: 'high', is64Bit: false);
      expect(c.profile, HardwareProfile.high);
    });
    test('sem override: 32-bit => low (Tinker Board S)', () {
      expect(HardwareCaps.resolve(override: null, is64Bit: false).profile,
          HardwareProfile.low);
    });
    test('sem override: 64-bit => high', () {
      expect(HardwareCaps.resolve(override: null, is64Bit: true).profile,
          HardwareProfile.high);
    });
  });
}
