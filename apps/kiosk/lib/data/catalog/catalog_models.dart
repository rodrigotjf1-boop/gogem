/// Modelos do snapshot publicado (`GET /catalogo/publicado`).
/// Parsing defensivo: ids podem vir como string (cuid) ou int; campos ausentes
/// caem em defaults seguros. O snapshot é imutável — nada aqui tem setter.
library;

String _id(dynamic v) => v?.toString() ?? '';
int _int(dynamic v, [int d = 0]) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? d);
bool _bool(dynamic v, [bool d = true]) => v is bool ? v : d;

class ExternalRef {
  const ExternalRef({required this.sistema, required this.codigoPdv, this.loja});
  final String sistema;
  final String codigoPdv;
  final String? loja;

  static List<ExternalRef> listFrom(dynamic json) => [
        if (json is List)
          for (final e in json.whereType<Map>())
            ExternalRef(
              sistema: '${e['sistema'] ?? ''}',
              codigoPdv: '${e['codigo_pdv'] ?? e['codigoPdv'] ?? ''}',
              loja: e['loja']?.toString(),
            ),
      ];

  /// Código PDV do Regem — a chave do de-para (nunca id interno).
  static String? codigoRegem(List<ExternalRef> refs) {
    for (final r in refs) {
      if (r.sistema == 'regem' && r.codigoPdv.isNotEmpty) return r.codigoPdv;
    }
    return null;
  }
}

class OpcaoComplemento {
  const OpcaoComplemento({
    required this.id,
    required this.nome,
    required this.precoCentavosDelta,
    required this.imagemUrl,
    required this.externalRefs,
  });
  final String id;
  final String nome;
  final int precoCentavosDelta;

  /// Foto da opção (Supabase Storage) ou `null`.
  final String? imagemUrl;
  final List<ExternalRef> externalRefs;

  factory OpcaoComplemento.fromJson(Map j) => OpcaoComplemento(
        id: _id(j['id']),
        nome: '${j['nome'] ?? ''}',
        precoCentavosDelta: _int(j['precoCentavosDelta']),
        imagemUrl: _urlOuNull(j['imagemUrl'] ?? j['imagem_url']),
        externalRefs: ExternalRef.listFrom(j['externalRefs']),
      );
}

class GrupoComplemento {
  const GrupoComplemento({
    required this.id,
    required this.nome,
    required this.min,
    required this.max,
    required this.obrigatorio,
    required this.opcoes,
  });
  final String id;
  final String nome;
  final int min;
  final int max;
  final bool obrigatorio;
  final List<OpcaoComplemento> opcoes;

  factory GrupoComplemento.fromJson(Map j) => GrupoComplemento(
        id: _id(j['id']),
        nome: '${j['nome'] ?? ''}',
        min: _int(j['min']),
        max: _int(j['max'], 1),
        obrigatorio: _bool(j['obrigatorio'], false),
        opcoes: [
          for (final o in (j['opcoes'] as List? ?? const []).whereType<Map>())
            OpcaoComplemento.fromJson(o)
        ],
      );
}

class Produto {
  const Produto({
    required this.id,
    required this.categoriaId,
    required this.nome,
    required this.descricao,
    required this.precoCentavos,
    required this.disponivel,
    required this.imagemUrl,
    required this.externalRefs,
    required this.grupos,
    this.upsell = const [],
  });
  final String id;
  final String categoriaId;
  final String nome;
  final String descricao;
  final int precoCentavos;
  final bool disponivel;

  /// URL pública da foto (Supabase Storage) ou `null` quando não há foto.
  final String? imagemUrl;
  final List<ExternalRef> externalRefs;
  final List<GrupoComplemento> grupos;

  /// IDs de produtos sugeridos no checkout ("Peça também", F2).
  final List<String> upsell;

  String? get codigoPdvRegem => ExternalRef.codigoRegem(externalRefs);

  factory Produto.fromJson(Map j) => Produto(
        id: _id(j['id']),
        categoriaId: _id(j['categoriaId'] ?? j['categoria_id']),
        nome: '${j['nome'] ?? ''}',
        descricao: '${j['descricao'] ?? ''}',
        precoCentavos: _int(j['precoCentavos']),
        disponivel: _bool(j['disponivel']),
        imagemUrl: _urlOuNull(j['imagemUrl'] ?? j['imagem_url']),
        externalRefs: ExternalRef.listFrom(j['externalRefs']),
        grupos: [
          for (final g in (j['grupos'] as List? ?? const []).whereType<Map>())
            GrupoComplemento.fromJson(g)
        ],
        upsell: [
          for (final u in (j['upsell'] as List? ?? const [])) _id(u)
        ],
      );
}

/// Normaliza a URL da imagem: string não-vazia → ela mesma; senão `null`.
String? _urlOuNull(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

class Categoria {
  const Categoria({required this.id, required this.nome});
  final String id;
  final String nome;
  factory Categoria.fromJson(Map j) =>
      Categoria(id: _id(j['id']), nome: '${j['nome'] ?? ''}');
}

class MenuSnapshot {
  const MenuSnapshot({required this.versao, required this.categorias, required this.produtos});
  final int versao;
  final List<Categoria> categorias;
  final List<Produto> produtos;

  List<Produto> produtosDa(String categoriaId) => [
        for (final p in produtos)
          if (p.categoriaId == categoriaId && p.disponivel) p
      ];

  /// Produto por id (ou `null`) — usado para resolver upsell (F2).
  Produto? porId(String id) {
    for (final p in produtos) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory MenuSnapshot.fromPublicadoJson(Map body) {
    final snap = (body['snapshot'] as Map?) ?? const {};
    return MenuSnapshot(
      versao: _int(body['versao']),
      categorias: [
        for (final c in (snap['categorias'] as List? ?? const []).whereType<Map>())
          Categoria.fromJson(c)
      ],
      produtos: [
        for (final p in (snap['produtos'] as List? ?? const []).whereType<Map>())
          Produto.fromJson(p)
      ],
    );
  }
}
