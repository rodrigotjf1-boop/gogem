/// Preços trafegam SEMPRE em centavos inteiros (CLAUDE.md). Formatação pt-BR.
String formatCentavos(int centavos) {
  final negativo = centavos < 0;
  final v = centavos.abs();
  final reais = v ~/ 100;
  final resto = (v % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  final digits = reais.toString();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    buf.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
  }
  return '${negativo ? '-' : ''}R\$ $buf,$resto';
}
