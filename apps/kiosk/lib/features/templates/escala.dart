import 'package:flutter/widgets.dart';

/// Medidas dos templates estão em px de DESENHO sobre uma tela de 1080 de largura
/// (retrato 1080×1920, docs/templates/00 §3.3). `context.dz(34)` converte para a tela real:
/// no totem de 1080 é 34; no harness de teste (800 de largura), ~25.
extension Escala on BuildContext {
  double get k => MediaQuery.sizeOf(this).width / 1080.0;
  double dz(num px) => px * k;
}
