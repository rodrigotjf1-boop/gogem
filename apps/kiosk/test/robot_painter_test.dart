import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/widgets/gogem_robot.dart';

void main() {
  testWidgets('GogemRobot renderiza sem erros nos extremos de animação',
      (tester) async {
    for (final cfg in [(0.0, 1.0), (1.0, 1.0), (0.5, 0.1), (1.0, 0.1)]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: GogemRobot(size: 300, paperExtent: cfg.$1, blink: cfg.$2)),
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
