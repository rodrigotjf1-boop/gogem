import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../comum/etapas.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../movimento.dart';
import 'vitrine_tokens.dart';

/// Peças visuais do template Vitrine usadas por mais de uma tela (docs/templates/02 §5).
/// Só desenho: nenhuma regra de pedido mora aqui.

/// Desfoque do vidro em px de desenho. Só use dentro de um `if (mov.blur)`.
ImageFilter vitrineDesfoque(BuildContext context, double sigma) =>
    ImageFilter.blur(sigmaX: context.dz(sigma), sigmaY: context.dz(sigma));

/// Vidro fosco (§3): com blur, `BackdropFilter` + branco translúcido e borda clara; sem
/// blur (perfil fraco, `Movimento.blur == false`), cor sólida translúcida — nunca um
/// `BackdropFilter`.
class VidroVitrine extends StatelessWidget {
  const VidroVitrine({
    super.key,
    required this.mov,
    required this.raio,
    required this.child,
    this.cor = vitrineVidro,
    this.corSemBlur = vitrineVidroSemBlur,
    this.borda = vitrineVidroBorda,
    this.larguraBorda = 2,
    this.sigma = 18,
    this.padding,
  });

  final Movimento mov;
  final BorderRadius raio;
  final Widget child;
  final Color cor;
  final Color corSemBlur;
  final Color? borda;

  /// Borda e desfoque em px de desenho.
  final double larguraBorda;
  final double sigma;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final caixa = DecoratedBox(
      decoration: BoxDecoration(
        color: mov.blur ? cor : corSemBlur,
        borderRadius: raio,
        border: borda == null ? null : Border.all(color: borda!, width: context.dz(larguraBorda)),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (!mov.blur) return caixa;
    return ClipRRect(
      borderRadius: raio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: context.dz(sigma), sigmaY: context.dz(sigma)),
        child: caixa,
      ),
    );
  }
}

/// Os quatro botões do template, todos em pílula (§5).
enum EstiloBotaoVitrine {
  /// Fundo `accent`, texto branco.
  primario,

  /// Vidro sobre a foto, texto branco e borda de 2 px.
  vidro,

  /// Transparente com borda `line2` (o "ghost" do protótipo).
  fantasma,

  /// Fundo `surface2` (o "soft" do protótipo).
  suave,
}

/// Botão pílula. `onTap == null` = desabilitado (35% de opacidade e sem toque).
/// Medidas em px de desenho: altura 124 (lg), 170 (xl) ou 96 (md).
class BotaoVitrine extends StatefulWidget {
  const BotaoVitrine({
    super.key,
    required this.rotulo,
    required this.onTap,
    this.estilo = EstiloBotaoVitrine.primario,
    this.icone,
    this.iconeFim,
    this.altura = 124,
    this.fonte = 34,
    this.padH = 44,
    this.mov = Movimento.parado,
    this.blur = true,
  });

  final String rotulo;
  final VoidCallback? onTap;
  final EstiloBotaoVitrine estilo;
  final IconData? icone;
  final IconData? iconeFim;
  final double altura;
  final double fonte;
  final double padH;
  final Movimento mov;

  /// Vidro com desfoque próprio. Desligue quando o botão já está sobre outro vidro
  /// (desfocar duas vezes custa caro e não muda o resultado).
  final bool blur;

  @override
  State<BotaoVitrine> createState() => _BotaoVitrineState();
}

class _BotaoVitrineState extends State<BotaoVitrine> {
  bool _baixo = false;

  void _pressao(bool v) {
    if (_baixo != v) setState(() => _baixo = v);
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final w = widget;
    final comBlur = w.estilo == EstiloBotaoVitrine.vidro && w.blur && w.mov.blur;
    final (Color fundo, Color tinta, Color? borda, double larguraBorda) = switch (w.estilo) {
      EstiloBotaoVitrine.primario => (t.accent, t.onAccent, null, 0),
      EstiloBotaoVitrine.vidro =>
        (comBlur || !w.blur ? vitrineVidro : vitrineVidroSemBlur, t.text, vitrineVidroBorda, 2),
      EstiloBotaoVitrine.fantasma => (const Color(0x00000000), t.text, t.line2, 3),
      EstiloBotaoVitrine.suave => (t.surface2, t.text, null, 0),
    };
    final h = context.dz(w.altura);
    final raio = BorderRadius.circular(h / 2);
    final fs = w.fonte;
    Widget caixa = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: context.dz(w.padH)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: raio,
        border: borda == null ? null : Border.all(color: borda, width: context.dz(larguraBorda)),
      ),
      // `scaleDown`: rótulo longo encolhe em vez de estourar — e o botão também funciona
      // numa `Row` sem largura definida (sem `Flexible` aqui dentro).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (w.icone != null) ...[
            Icon(w.icone, size: context.dz(fs * 1.15), color: tinta),
            SizedBox(width: context.dz(16)),
          ],
          Text(w.rotulo, maxLines: 1, style: context.vTexto(fs, peso: FontWeight.w800, cor: tinta, altura: 1)),
          if (w.iconeFim != null) ...[
            SizedBox(width: context.dz(14)),
            Icon(w.iconeFim, size: context.dz(fs * 1.05), color: tinta),
          ],
        ]),
      ),
    );
    if (comBlur) {
      caixa = ClipRRect(
        borderRadius: raio,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: context.dz(18), sigmaY: context.dz(18)),
          child: caixa,
        ),
      );
    }
    final ativo = w.onTap != null;
    return Semantics(
      button: true,
      enabled: ativo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: ativo ? (_) => _pressao(true) : null,
        onTapUp: ativo ? (_) => _pressao(false) : null,
        onTapCancel: ativo ? () => _pressao(false) : null,
        onTap: w.onTap,
        child: AnimatedScale(
          scale: _baixo ? .97 : 1,
          duration: w.mov.anima ? const Duration(milliseconds: 150) : Duration.zero,
          child: Opacity(opacity: ativo ? 1 : .35, child: caixa),
        ),
      ),
    );
  }
}

/// Logo da loja (§4): `logoUrl`, ou o `nomeLoja` em minúsculas com o ponto final em
/// `accent`, ou — sem nenhum dos dois — o "mordida." padrão do template.
class LogoVitrineMarca extends StatelessWidget {
  const LogoVitrineMarca({super.key, this.nomeLoja, this.logoUrl, this.tamanho = 58});

  final String? nomeLoja;
  final String? logoUrl;

  /// Tamanho da fonte em px de desenho (58 no descanso ×1,1; 45 no topo das telas).
  final double tamanho;

  static String nomeDaMarca(String? nomeLoja) {
    final base = (nomeLoja ?? '').trim().toLowerCase();
    final semPonto = base.replaceFirst(RegExp(r'\.+$'), '');
    return semPonto.isEmpty ? 'mordida' : semPonto;
  }

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      final alto = context.dz(tamanho * 1.3);
      return SizedBox(
        height: alto,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          memCacheHeight: (alto * MediaQuery.devicePixelRatioOf(context)).round().clamp(32, 400),
          placeholder: (_, __) => SizedBox(width: alto),
          errorWidget: (_, __, ___) => _nome(context),
        ),
      );
    }
    return _nome(context);
  }

  Widget _nome(BuildContext context) => Text.rich(
        TextSpan(
          text: nomeDaMarca(nomeLoja),
          style: context.vDisplay(tamanho, altura: 1),
          children: [TextSpan(text: '.', style: TextStyle(color: vitrineTokens.accent))],
        ),
        key: const ValueKey('logo-vitrine'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

/// O logo nas telas que não recebem a loja pelas props: lê a aparência publicada.
class LogoVitrine extends ConsumerWidget {
  const LogoVitrine({super.key, this.tamanho = 45});
  final double tamanho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(aparenciaProvider).valueOrNull;
    return LogoVitrineMarca(nomeLoja: ap?.nomeLoja, logoUrl: ap?.logoUrl, tamanho: tamanho);
  }
}

/// Topo das telas internas (protótipo `.tb`): logo, "Voltar", "Cancelar" e a barra de
/// etapas. [sobreFoto] = versão do feed, com os botões em vidro sobre a foto.
class TopoVitrine extends StatelessWidget {
  const TopoVitrine({
    super.key,
    this.etapa,
    this.onVoltar,
    this.onCancelar,
    this.mov = Movimento.parado,
    this.sobreFoto = false,
  });

  final int? etapa;
  final VoidCallback? onVoltar;
  final VoidCallback? onCancelar;
  final Movimento mov;
  final bool sobreFoto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(40), context.dz(48), context.dz(16)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Altura mínima dos botões do topo: sem "Voltar"/"Cancelar" as etapas não sobem.
        Row(children: [
          SizedBox(height: context.dz(72)),
          const Expanded(child: Align(alignment: Alignment.centerLeft, child: LogoVitrine())),
          if (onVoltar != null) ...[
            SizedBox(width: context.dz(12)),
            _BotaoTopo(
              key: const ValueKey('topo-voltar'),
              rotulo: 'Voltar',
              icone: Icons.chevron_left_rounded,
              onTap: onVoltar!,
              cancelar: false,
              sobreFoto: sobreFoto,
              mov: mov,
            ),
          ],
          if (onCancelar != null) ...[
            SizedBox(width: context.dz(12)),
            _BotaoTopo(
              key: const ValueKey('topo-cancelar'),
              rotulo: 'Cancelar',
              icone: Icons.close_rounded,
              onTap: onCancelar!,
              cancelar: true,
              sobreFoto: sobreFoto,
              mov: mov,
            ),
          ],
        ]),
        if (etapa != null) ...[
          SizedBox(height: context.dz(26)),
          Etapas(atual: etapa!, tokens: vitrineTokens, mov: mov),
        ],
      ]),
    );
  }
}

class _BotaoTopo extends StatelessWidget {
  const _BotaoTopo({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.onTap,
    required this.cancelar,
    required this.sobreFoto,
    required this.mov,
  });

  final String rotulo;
  final IconData icone;
  final VoidCallback onTap;
  final bool cancelar;
  final bool sobreFoto;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final h = context.dz(72);
    final tinta = cancelar ? (sobreFoto ? const Color(0xD9FFFFFF) : t.muted) : t.text;
    final conteudo = Padding(
      padding: EdgeInsets.symmetric(horizontal: context.dz(26)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: context.dz(cancelar ? 30 : 36), color: tinta),
        SizedBox(width: context.dz(10)),
        Text(rotulo, style: context.vTexto(26, cor: tinta, altura: 1)),
      ]),
    );
    final raio = BorderRadius.circular(h / 2);
    final Widget caixa;
    if (cancelar) {
      caixa = Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: raio,
          border: Border.all(color: sobreFoto ? vitrineVidroBorda : t.line, width: context.dz(2)),
        ),
        child: conteudo,
      );
    } else if (sobreFoto) {
      caixa = SizedBox(
        height: h,
        child: VidroVitrine(mov: mov, raio: raio, borda: null, sigma: 14, child: Center(child: conteudo)),
      );
    } else {
      caixa = Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.surface2, borderRadius: raio),
        child: conteudo,
      );
    }
    return Semantics(
      button: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: caixa),
    );
  }
}

/// Entrada de tela do template (§7, "troca de tela"): zoom 1,06 → 1 com fade em 550 ms.
/// A rota é do go_router (fora do template); o efeito roda aqui, na montagem da tela.
/// Sem animação, mostra direto.
class EntradaVitrine extends StatefulWidget {
  const EntradaVitrine({super.key, required this.mov, required this.child});
  final Movimento mov;
  final Widget child;

  @override
  State<EntradaVitrine> createState() => _EntradaVitrineState();
}

class _EntradaVitrineState extends State<EntradaVitrine> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _curva;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(550));
    _curva = CurvedAnimation(parent: _c, curve: const Cubic(.2, .8, .2, 1));
    if (widget.mov.anima) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.06, end: 1).animate(_curva),
        child: widget.child,
      ),
    );
  }
}

/// Arte de produto SEM foto (§6.2): fundo `0xFF141414`, disco `accent` de 900 e o recorte
/// (`.png`) flutuando ±18 px em 3,6 s; sem imagem nenhuma, o ícone de prato em `onAccent`.
/// Posições em px de desenho sobre a tela 1080×1920 (o protótipo `.vcolor`/`.vcut`).
class ArteSemFotoVitrine extends StatefulWidget {
  const ArteSemFotoVitrine({super.key, required this.url, required this.mov});

  /// URL do recorte (`.png`) ou `null`.
  final String? url;
  final Movimento mov;

  @override
  State<ArteSemFotoVitrine> createState() => _ArteSemFotoVitrineState();
}

class _ArteSemFotoVitrineState extends State<ArteSemFotoVitrine> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // `bob` do protótipo: sobe 18 px e volta — 1,8 s para cada lado.
    _c = AnimationController(vsync: this, duration: widget.mov.d(1800));
    if (vitrineMovimentoCheio(widget.mov)) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final temRecorte = ProdutoArte.ehRecorte(widget.url);
    final arte = temRecorte
        ? ProdutoArte(url: widget.url, tokens: t, escalaRecorte: 1, fundo: const Color(0x00000000))
        : Center(
            child: Icon(Icons.restaurant_menu_rounded,
                key: const ValueKey('arte-sem-foto-icone'), size: context.dz(360), color: t.onAccent),
          );
    return ColoredBox(
      color: const Color(0xFF141414),
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned(
          left: context.dz(90),
          top: context.dz(360),
          width: context.dz(900),
          height: context.dz(900),
          child: const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xF2FF5B2E), shape: BoxShape.circle),
          ),
        ),
        Positioned(
          left: context.dz(120),
          top: context.dz(420),
          width: context.dz(840),
          height: context.dz(700),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -context.dz(18) * Curves.easeInOut.transform(_c.value)),
                child: child,
              ),
              child: arte,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Título grande em Syne que NUNCA quebra uma palavra no meio: a Syne 800 é muito larga e,
/// a 170 (story) ou 118 (feed), um nome como "Clássico" não cabe na linha. Se a palavra mais
/// longa não couber na largura, a fonte encolhe só o necessário. Não use dentro de
/// `IntrinsicHeight` (mede com `LayoutBuilder`).
class TituloVitrine extends StatelessWidget {
  const TituloVitrine(this.texto, {super.key, required this.estilo, this.maxLines = 3, this.textAlign});

  final String texto;
  final TextStyle estilo;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var estiloFinal = estilo;
      if (c.maxWidth.isFinite && estilo.fontSize != null) {
        final escalaTexto = MediaQuery.textScalerOf(context);
        var maior = 0.0;
        for (final palavra in texto.split(RegExp(r'\s+'))) {
          if (palavra.isEmpty) continue;
          final tp = TextPainter(
            text: TextSpan(text: palavra, style: estilo),
            textDirection: TextDirection.ltr,
            textScaler: escalaTexto,
            maxLines: 1,
          )..layout();
          if (tp.width > maior) maior = tp.width;
          tp.dispose();
        }
        if (maior > c.maxWidth) {
          final f = c.maxWidth / maior * .98;
          estiloFinal = estilo.copyWith(
            fontSize: estilo.fontSize! * f,
            letterSpacing: estilo.letterSpacing == null ? null : estilo.letterSpacing! * f,
          );
        }
      }
      return Text(texto,
          maxLines: maxLines, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: estiloFinal);
    });
  }
}

/// Aviso de segurança da confirmação e do pagamento (ERR-022/V20): borda e texto no
/// acento, fundo `hi`.
class AvisoVitrine extends StatelessWidget {
  const AvisoVitrine({super.key, required this.child, this.icone});
  final Widget child;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.dz(32), vertical: context.dz(22)),
      decoration: BoxDecoration(
        color: t.hi,
        borderRadius: BorderRadius.circular(context.dz(28)),
        border: Border.all(color: t.accent, width: context.dz(2)),
      ),
      child: Row(children: [
        if (icone != null) ...[
          Icon(icone, color: t.accent, size: context.dz(44)),
          SizedBox(width: context.dz(20)),
        ],
        Expanded(child: child),
      ]),
    );
  }
}

/// Rola quando não cabe (telas baixas: harness 800×600, totem em paisagem) e, quando
/// cabe, estica a coluna até a altura toda — para o `Spacer` empurrar o rodapé.
class ColunaQueRola extends StatelessWidget {
  const ColunaQueRola({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (c.maxHeight - padding.vertical).clamp(0.0, double.infinity),
          ),
          child: IntrinsicHeight(
            child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
          ),
        ),
      ),
    );
  }
}
