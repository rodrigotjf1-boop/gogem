import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';

/// Tema das telas SEM versão do template (admin do totem, pareamento, carregando).
/// A paleta recomendada do Diner 58 e do Estúdio é CLARA; com ela no tema global, o texto
/// claro das telas do operador ficaria sobre fundo claro (docs/templates/03-estudio.md §9).
void main() {
  test('com template novo, as telas sem variante ficam no tema escuro padrão do GoGeM', () {
    final ap = Aparencia.fromJson({
      'temaPreset': 'diner',
      'corFundo': '#FFF4E2',
      'corPainel': '#FFFFFF',
      'corPrimaria': '#D3202A',
    });
    final tema = temaDoApp(ap);
    expect(tema.brightness, Brightness.dark);
    expect(tema.scaffoldBackgroundColor, Aparencia.padrao.corFundo);
    expect(tema.colorScheme.primary, Aparencia.padrao.corPrimaria);
  });

  test('sem template novo (Brasa, GoGen), vale a aparência da loja como hoje', () {
    for (final preset in ['brasa', 'gogen']) {
      final ap = Aparencia.fromJson({'temaPreset': preset, 'corFundo': '#101820'});
      expect(temaDoApp(ap).scaffoldBackgroundColor, const Color(0xFF101820), reason: preset);
    }
  });
}
