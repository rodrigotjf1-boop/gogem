import 'package:flutter/material.dart';

/// Paleta e helpers do template **GoGen** (identidade "flame" fixa — o GoGen tem
/// cara própria, independente das cores da loja). Espelha as variáveis :root do
/// template HTML.
class GogenColors {
  const GogenColors._();
  static const flame1 = Color(0xFFFF5A1F);
  static const flame2 = Color(0xFFFF8A00);
  static const flame3 = Color(0xFFFFB000);
  static const ink = Color(0xFF1B1410);
  static const ink2 = Color(0xFF4A3B32);
  static const cream = Color(0xFFFFF8F0);
  static const cream2 = Color(0xFFFFEFDD);
  static const card = Colors.white;
  static const ok = Color(0xFF12A150);
  static const pix = Color(0xFF32BCAD);

  /// Gradiente flame (135°) — usado em botões, selos, destaque da roleta.
  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [flame1, flame2, flame3],
    stops: [0, .55, 1],
  );
}

/// "#RRGGBB" (ou "RRGGBB") → Color; inválido/nulo → null.
Color? gogenCorHex(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Emoji por categoria — quando a categoria não tem imagem/emoji próprios,
/// derivamos um ícone por palavra-chave do nome. Fallback genérico.
String gogenEmojiCategoria(String nome) {
  final n = nome.toLowerCase();
  bool tem(List<String> ks) => ks.any(n.contains);
  if (tem(['promo', 'oferta'])) return '🔥';
  if (tem(['combo'])) return '🍟';
  if (tem(['burg', 'lanche', 'hamb'])) return '🍔';
  if (tem(['frango', 'chicken', 'crispy'])) return '🍗';
  if (tem(['acomp', 'batata', 'porç', 'porc'])) return '🍟';
  if (tem(['bebida', 'suco', 'refri', 'drink'])) return '🥤';
  if (tem(['sobrem', 'doce', 'sorvete', 'shake'])) return '🍦';
  if (tem(['pizza'])) return '🍕';
  if (tem(['salada', 'veg'])) return '🥗';
  if (tem(['café', 'cafe'])) return '☕';
  return '🍽️';
}
