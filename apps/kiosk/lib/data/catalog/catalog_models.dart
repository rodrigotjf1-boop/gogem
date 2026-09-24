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
    this.disponivel = true,
  });
  final String id;
  final String nome;
  final int precoCentavosDelta;

  /// Foto da opção (Supabase Storage) ou `null`.
  final String? imagemUrl;
  final List<ExternalRef> externalRefs;

  /// Opção pausada no painel ("acabou o bacon") não é oferecida. O app ignorava o campo e
  /// seguia vendendo a opção indisponível (ERR-024).
  final bool disponivel;

  factory OpcaoComplemento.fromJson(Map j) => OpcaoComplemento(
        id: _id(j['id']),
        nome: '${j['nome'] ?? ''}',
        precoCentavosDelta: _int(j['precoCentavosDelta']),
        imagemUrl: _urlOuNull(j['imagemUrl'] ?? j['imagem_url']),
        externalRefs: ExternalRef.listFrom(j['externalRefs']),
        disponivel: _bool(j['disponivel']),
      );

  OpcaoComplemento comDisponivel(bool d) => OpcaoComplemento(
      id: id,
      nome: nome,
      precoCentavosDelta: precoCentavosDelta,
      imagemUrl: imagemUrl,
      externalRefs: externalRefs,
      disponivel: d);
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

  factory GrupoComplemento.fromJson(Map j) {
    final opcoes = [
      for (final o in (j['opcoes'] as List? ?? const []).whereType<Map>())
        OpcaoComplemento.fromJson(o)
    ];
    return GrupoComplemento(
      id: _id(j['id']),
      nome: '${j['nome'] ?? ''}',
      min: _int(j['min']),
      // `max` nulo = SEM LIMITE (é assim que o painel grava). Lido como 1, o grupo
      // "escolha quantos quiser" virava escolha única no totem (ERR-025).
      max: j['max'] == null
          ? (opcoes.isEmpty ? 1 : opcoes.length)
          : _int(j['max'], 1),
      obrigatorio: _bool(j['obrigatorio'], false),
      opcoes: opcoes,
    );
  }

  GrupoComplemento comOpcoes(List<OpcaoComplemento> novas) => GrupoComplemento(
      id: id,
      nome: nome,
      min: min,
      max: max,
      obrigatorio: obrigatorio,
      opcoes: novas);

  /// Mínimo efetivo: `obrigatorio` com `min = 0` conta como 1.
  int get minimo => obrigatorio && min == 0 ? 1 : min;
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
    this.selo,
    this.upsell = const [],
  });
  final String id;
  final String categoriaId;
  final String nome;
  final String descricao;
  final int precoCentavos;
  final bool disponivel;

  /// Selo de destaque no card (F4) — ex.: "Mais vendido". Nulo = sem selo.
  final String? selo;

  /// URL pública da foto (Supabase Storage) ou `null` quando não há foto.
  final String? imagemUrl;
  final List<ExternalRef> externalRefs;
  final List<GrupoComplemento> grupos;

  /// IDs de produtos sugeridos no checkout ("Peça também", F2).
  final List<String> upsell;

  String? get codigoPdvRegem => ExternalRef.codigoRegem(externalRefs);

  Produto copyWith({bool? disponivel, List<GrupoComplemento>? grupos}) => Produto(
        id: id,
        categoriaId: categoriaId,
        nome: nome,
        descricao: descricao,
        precoCentavos: precoCentavos,
        disponivel: disponivel ?? this.disponivel,
        imagemUrl: imagemUrl,
        externalRefs: externalRefs,
        grupos: grupos ?? this.grupos,
        selo: selo,
        upsell: upsell,
      );

  factory Produto.fromJson(Map j) => Produto(
        id: _id(j['id']),
        categoriaId: _id(j['categoriaId'] ?? j['categoria_id']),
        nome: '${j['nome'] ?? ''}',
        descricao: '${j['descricao'] ?? ''}',
        precoCentavos: _int(j['precoCentavos']),
        disponivel: _bool(j['disponivel']),
        imagemUrl: _urlOuNull(j['imagemUrl'] ?? j['imagem_url']),
        externalRefs: ExternalRef.listFrom(j['externalRefs']),
        selo: () {
          final s = j['selo']?.toString().trim();
          return (s == null || s.isEmpty) ? null : s;
        }(),
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
  const Categoria({
    required this.id,
    required this.nome,
    this.imagemUrl,
    this.emoji,
    this.cor,
  });
  final String id;
  final String nome;

  /// Arte da categoria (roleta do totem): imagem ▸ emoji ▸ cor. Todos opcionais
  /// — vêm do admin; sem eles o totem cai no emoji derivado do nome.
  final String? imagemUrl;
  final String? emoji;
  final String? cor; // hex "#RRGGBB"

  factory Categoria.fromJson(Map j) => Categoria(
        id: _id(j['id']),
        nome: '${j['nome'] ?? ''}',
        imagemUrl: _urlOuNull(j['imagemUrl'] ?? j['imagem_url']),
        emoji: () {
          final e = j['emoji']?.toString().trim();
          return (e == null || e.isEmpty) ? null : e;
        }(),
        cor: () {
          final c = j['cor']?.toString().trim();
          return (c == null || c.isEmpty) ? null : c;
        }(),
      );
}

/// O que está pausado AGORA no painel (vem em toda resposta do sync da nuvem, por cima do
/// retrato publicado — ERR-017). Ausente (servidor da loja, API antiga) = vale o retrato.
class Disponibilidade {
  const Disponibilidade({
    this.produtosIndisponiveis = const {},
    this.categoriasPausadas = const {},
    this.opcoesIndisponiveis = const {},
  });
  final Set<String> produtosIndisponiveis;
  final Set<String> categoriasPausadas;
  final Set<String> opcoesIndisponiveis;

  static Disponibilidade? fromJson(Object? j) {
    if (j is! Map) return null;
    Set<String> ids(Object? v) =>
        {for (final x in (v is List ? v : const [])) '$x'};
    return Disponibilidade(
      produtosIndisponiveis: ids(j['produtosIndisponiveis']),
      categoriasPausadas: ids(j['categoriasPausadas']),
      opcoesIndisponiveis: ids(j['opcoesIndisponiveis']),
    );
  }
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

  /// O cardápio que o cliente VÊ: o retrato publicado com a disponibilidade aplicada.
  ///
  /// - com [d] (nuvem): a disponibilidade AO VIVO manda — pausar e despausar no painel chega
  ///   sem publicar; categoria pausada sai com os produtos dela;
  /// - sem [d]: vale o `disponivel` do próprio retrato;
  /// - opção indisponível sai da lista (ERR-024); e produto cuja etapa obrigatória ficou sem
  ///   opções suficientes sai da venda — o cliente não conseguiria concluí-lo.
  MenuSnapshot aplicarDisponibilidade(Disponibilidade? d) {
    final pausadas = d?.categoriasPausadas ?? const <String>{};
    final produtosVisiveis = <Produto>[];
    for (final p in produtos) {
      if (pausadas.contains(p.categoriaId)) continue;
      var disponivel =
          d == null ? p.disponivel : !d.produtosIndisponiveis.contains(p.id);
      final grupos = <GrupoComplemento>[];
      for (final g in p.grupos) {
        final opcoes = [
          for (final o in g.opcoes)
            if (d == null ? o.disponivel : !d.opcoesIndisponiveis.contains(o.id))
              o.comDisponivel(true)
        ];
        if (opcoes.length < g.minimo) disponivel = false;
        grupos.add(g.comOpcoes(opcoes));
      }
      produtosVisiveis.add(p.copyWith(disponivel: disponivel, grupos: grupos));
    }
    return MenuSnapshot(
      versao: versao,
      categorias: [
        for (final c in categorias)
          if (!pausadas.contains(c.id)) c
      ],
      produtos: produtosVisiveis,
    );
  }

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
