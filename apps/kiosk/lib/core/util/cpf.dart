/// Validação de CPF (dígitos verificadores). Entrada: só dígitos.
bool cpfValido(String cpf) {
  final d = cpf.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false; // 111.111...
  int dv(int len) {
    var soma = 0;
    for (var i = 0; i < len; i++) {
      soma += int.parse(d[i]) * (len + 1 - i);
    }
    final r = (soma * 10) % 11;
    return r == 10 ? 0 : r;
  }
  return dv(9) == int.parse(d[9]) && dv(10) == int.parse(d[10]);
}

String formatCpf(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  final b = StringBuffer();
  for (var i = 0; i < d.length && i < 11; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}
