import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';

void main() {
  test('F3: parse do temaPreset e das legendas do descanso', () {
    final ap = Aparencia.fromJson({
      'temaPreset': 'brasa',
      'descansoTipo': 'carrossel',
      'descansoMidias': [
        {
          'url': 'https://x/1.jpg',
          'kicker': 'Feito na brasa',
          'titulo': 'Mister Double',
          'subtitulo': 'Dois blends',
        },
        {'url': 'https://x/2.jpg'}, // sem legenda
      ],
    });

    expect(ap.brasa, isTrue);
    expect(ap.carrossel, isTrue);
    expect(ap.descansoMidias, hasLength(2));
    final primeira = ap.descansoMidias.first;
    expect(primeira.url, 'https://x/1.jpg');
    expect(primeira.kicker, 'Feito na brasa');
    expect(primeira.titulo, 'Mister Double');
    expect(primeira.temLegenda, isTrue);
    expect(ap.descansoMidias[1].temLegenda, isFalse);
  });

  test('F3: defaults — sem temaPreset cai em padrao; url string simples', () {
    final ap = Aparencia.fromJson({
      'descansoMidias': ['https://x/só-url.jpg'],
    });
    expect(ap.brasa, isFalse);
    expect(ap.temaPreset, 'padrao');
    expect(ap.descansoMidias.single.url, 'https://x/só-url.jpg');
    expect(ap.descansoMidias.single.temLegenda, isFalse);
  });
}
