import 'dart:typed_data';
import 'commands.dart';

/// Builder de cupom ESC/POS (não-fiscal). Texto em CP850 (acentos PT-BR).
class EscPosBuilder {
  final BytesBuilder _b = BytesBuilder();

  EscPosBuilder() {
    _b.add(Cmd.init);
    _b.add(Cmd.cp850);
  }

  static const _mapa = {
    'á':0xA0,'à':0x85,'â':0x83,'ã':0xC6,'é':0x82,'ê':0x88,'í':0xA1,
    'ó':0xA2,'ô':0x93,'õ':0xE4,'ú':0xA3,'ç':0x87,
    'Á':0xB5,'À':0xB7,'Â':0xB6,'Ã':0xC7,'É':0x90,'Ê':0xD2,'Í':0xD6,
    'Ó':0xE0,'Ô':0xE2,'Õ':0xE5,'Ú':0xE9,'Ç':0x80,'º':0xA7,'ª':0xA6,
  };

  Uint8List _cp850(String s) {
    final out = <int>[];
    for (final ch in s.split('')) {
      final c = ch.codeUnitAt(0);
      if (c < 0x80) {
        out.add(c);
      } else {
        out.add(_mapa[ch] ?? 0x3F); // '?' para o que não mapear
      }
    }
    return Uint8List.fromList(out);
  }

  EscPosBuilder texto(String s, {bool negrito = false, int tamanho = 1, bool centro = false}) {
    _b.add(centro ? Cmd.alignCenter : Cmd.alignLeft);
    if (negrito) _b.add(Cmd.boldOn);
    if (tamanho > 1) _b.add(Cmd.size(tamanho, tamanho));
    _b.add(_cp850(s));
    _b.add(Uint8List.fromList([0x0A]));
    if (tamanho > 1) _b.add(Cmd.size(1, 1));
    if (negrito) _b.add(Cmd.boldOff);
    return this;
  }

  EscPosBuilder linha([String ch = '-', int cols = 42]) => texto(ch * cols);

  /// item alinhado: nome à esquerda, valor à direita (largura padrão 42 col).
  EscPosBuilder itemValor(String nome, String valor, {int cols = 42}) {
    final espaco = cols - nome.length - valor.length;
    return texto(espaco > 0 ? '$nome${' ' * espaco}$valor' : '$nome $valor');
  }

  EscPosBuilder corte() {
    _b.add(Cmd.feed3);
    _b.add(Cmd.cut);
    return this;
  }

  Uint8List build() => _b.toBytes();
}
