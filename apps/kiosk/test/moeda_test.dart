import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/util/moeda.dart';

void main() {
  test('formatCentavos pt-BR', () {
    expect(formatCentavos(0), 'R\$ 0,00');
    expect(formatCentavos(700), 'R\$ 7,00');
    expect(formatCentavos(2990), 'R\$ 29,90');
    expect(formatCentavos(123456789), 'R\$ 1.234.567,89');
    expect(formatCentavos(-500), '-R\$ 5,00');
  });
}
