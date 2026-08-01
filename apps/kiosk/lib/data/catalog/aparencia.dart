import 'package:flutter/material.dart';

/// Uma mídia do descanso (F3): url + legendas editoriais opcionais por slide.
class DescansoMidia {
  const DescansoMidia({
    required this.url,
    this.kicker,
    this.titulo,
    this.subtitulo,
  });
  final String url;
  final String? kicker;
  final String? titulo;
  final String? subtitulo;

  bool get temLegenda =>
      (kicker != null && kicker!.isNotEmpty) ||
      (titulo != null && titulo!.isNotEmpty) ||
      (subtitulo != null && subtitulo!.isNotEmpty);
}

/// Aparência do totem (Fase 6) — vem do `/catalogo/publicado` (por loja) e
/// re-tematiza o app no sync. Parsing defensivo: campo ausente cai no padrão
/// GoGeM. Cores chegam em hex ("#RRGGBB"); aqui viram `Color`.
class Aparencia {
  const Aparencia({
    required this.corPrimaria,
    required this.corDestaque,
    required this.corFundo,
    required this.corPainel,
    required this.raio,
    required this.nomeLoja,
    required this.logoUrl,
    required this.fonteDisplay,
    required this.temaPreset,
    required this.descansoTipo,
    required this.descansoIntervaloSeg,
    required this.descansoMidias,
    required this.chamada,
    required this.precoIsca,
    required this.estiloCard,
    required this.animacoes,
  });

  final Color corPrimaria;
  final Color corDestaque;
  final Color corFundo;
  final Color corPainel;
  final double raio;
  final String? nomeLoja;
  final String? logoUrl;
  final String fonteDisplay; // 'Tektur' | 'Poppins' | 'Montserrat'
  final String temaPreset; // 'padrao' | 'brasa' | 'burger'
  final String descansoTipo; // 'padrao' | 'carrossel'
  final int descansoIntervaloSeg;
  final List<DescansoMidia> descansoMidias;
  final String chamada;
  final String? precoIsca;
  final String estiloCard; // 'cheia' | 'lateral'
  final String animacoes; // 'cheio' | 'reduzido' | 'off'

  /// Padrão da marca GoGeM (fallback / offline sem aparência salva).
  static const padrao = Aparencia(
    corPrimaria: Color(0xFFFFC24B),
    corDestaque: Color(0xFF3ECF8E),
    corFundo: Color(0xFF0F1713),
    corPainel: Color(0xFF16211B),
    raio: 16,
    nomeLoja: null,
    logoUrl: null,
    fonteDisplay: 'Tektur',
    temaPreset: 'padrao',
    descansoTipo: 'padrao',
    descansoIntervaloSeg: 6,
    descansoMidias: [],
    chamada: 'TOQUE PARA PEDIR',
    precoIsca: null,
    estiloCard: 'cheia',
    animacoes: 'cheio',
  );

  bool get carrossel => descansoTipo == 'carrossel' && descansoMidias.isNotEmpty;
  bool get brasa => temaPreset == 'brasa';
  bool get burger => temaPreset == 'burger';

  /// Presets "editoriais" (Brasa/Burger House): tipografia display maior, peso e
  /// caixa-alta, fundo/cards quentes. Agrupa os tratamentos comuns aos dois.
  bool get editorial => brasa || burger;
  bool get cardLateral => estiloCard == 'lateral';
  bool get semAnimacao => animacoes == 'off';
  bool get animacaoReduzida => animacoes == 'reduzido';

  factory Aparencia.fromJson(Object? raw) {
    if (raw is! Map) return padrao;
    String? s(String k) {
      final v = raw[k];
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    String? txt(Object? v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final midias = <DescansoMidia>[];
    final m = raw['descansoMidias'];
    if (m is List) {
      for (final e in m) {
        if (e is Map && e['url'] != null) {
          final u = e['url'].toString().trim();
          if (u.isNotEmpty) {
            midias.add(DescansoMidia(
              url: u,
              kicker: txt(e['kicker']),
              titulo: txt(e['titulo']),
              subtitulo: txt(e['subtitulo']),
            ));
          }
        } else if (e is String && e.trim().isNotEmpty) {
          midias.add(DescansoMidia(url: e.trim()));
        }
      }
    }

    return Aparencia(
      corPrimaria: _cor(s('corPrimaria'), padrao.corPrimaria),
      corDestaque: _cor(s('corDestaque'), padrao.corDestaque),
      corFundo: _cor(s('corFundo'), padrao.corFundo),
      corPainel: _cor(s('corPainel'), padrao.corPainel),
      raio: (raw['raio'] is num ? (raw['raio'] as num).toDouble() : 16.0)
          .clamp(0.0, 40.0)
          .toDouble(),
      nomeLoja: s('nomeLoja'),
      logoUrl: s('logoUrl'),
      fonteDisplay: s('fonteDisplay') ?? 'Tektur',
      temaPreset: s('temaPreset') ?? 'padrao',
      descansoTipo: s('descansoTipo') ?? 'padrao',
      descansoIntervaloSeg:
          (raw['descansoIntervaloSeg'] is num ? (raw['descansoIntervaloSeg'] as num).toInt() : 6)
              .clamp(2, 60)
              .toInt(),
      descansoMidias: midias,
      chamada: s('chamada') ?? 'TOQUE PARA PEDIR',
      precoIsca: s('precoIsca'),
      estiloCard: s('estiloCard') ?? 'cheia',
      animacoes: s('animacoes') ?? 'cheio',
    );
  }
}

/// "#RRGGBB" (ou "RRGGBB") → Color; inválido → fallback.
Color _cor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}
