import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../comum/etapas.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../movimento.dart';
import 'diner_tokens.dart';
import 'pintores.dart';

const _t = dinerTokens;

/// Tema CLARO local das telas do Diner: o `temaDe` do app monta `ColorScheme.dark`, então
/// cada tela do template embrulha o conteúdo neste tema (spinner, cursor, seleção e textos
/// sem estilo ficam legíveis sobre o creme) — docs/templates/03 §9 e 05 §3.
class DinerTema extends StatelessWidget {
  const DinerTema({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _t.bg,
        canvasColor: _t.bg,
        colorScheme: ColorScheme.light(
          primary: _t.accent,
          onPrimary: _t.onAccent,
          secondary: _t.accent2,
          onSecondary: _t.onAccent2,
          surface: _t.bg,
          onSurface: _t.text,
          error: _t.err,
          onError: _t.onAccent,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: _t.accent),
        textSelectionTheme: TextSelectionThemeData(cursorColor: _t.accent),
      ),
      child: DefaultTextStyle(
        style: _t.texto(20, cor: _t.text),
        child: IconTheme(data: IconThemeData(color: _t.text), child: child),
      ),
    );
  }
}

/// Entrada de tela do Diner: sobe 60 px e cresce de 0,97 a 1 com um "quique"
/// (600 ms, `Cubic(.3,1.4,.5,1)`). Reduzido, fraco ou sem animação: instantâneo.
class DinerEntrada extends StatelessWidget {
  const DinerEntrada({super.key, required this.mov, required this.child});
  final Movimento mov;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!mov.anima || !mov.particulas) return child;
    final sobe = context.dz(60);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: mov.d(600),
      curve: const Cubic(.3, 1.4, .5, 1),
      child: child,
      builder: (_, v, filho) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * sobe),
          child: Transform.scale(scale: .97 + .03 * v, child: filho),
        ),
      ),
    );
  }
}

/// Logo do topo. Sem `logoUrl` nem `nomeLoja`, o padrão do template: "Diner" em Yellowtail
/// + "58" em Bungee num bloco escuro girado −6° + "BURGERS · SHAKES" (docs/templates/05 §4).
/// Com a loja: a logo (se houver) e o nome em Yellowtail.
class DinerLogo extends StatelessWidget {
  const DinerLogo({
    super.key,
    this.nomeLoja,
    this.logoUrl,
    this.escala = 1,
    this.invertido = false,
  });

  final String? nomeLoja;
  final String? logoUrl;
  final double escala;

  /// Sobre o cabeçalho vermelho: tinta creme, com sombra de texto marrom.
  final bool invertido;

  @override
  Widget build(BuildContext context) {
    double s(num px) => context.dz(px * escala);
    final corNome = invertido ? _t.bg : _t.accent;
    final sombraNome = invertido ? [Shadow(color: _t.text, offset: Offset(s(3), s(3)))] : const <Shadow>[];
    final nome = (nomeLoja ?? '').trim();
    final logo = (logoUrl ?? '').trim();
    if (nome.isNotEmpty || logo.isNotEmpty) {
      return Row(
        key: const ValueKey('diner-logo-loja'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo.isNotEmpty)
            SizedBox(
              height: s(84),
              width: s(nome.isEmpty ? 260 : 110),
              child: CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                memCacheHeight: (s(84) * MediaQuery.devicePixelRatioOf(context)).round().clamp(32, 400),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (logo.isNotEmpty && nome.isNotEmpty) SizedBox(width: s(12)),
          if (nome.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: s(430)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child:
                    Text(nome, maxLines: 1, style: dinerScript(s(66), cor: corNome, sombras: sombraNome, altura: 1.05)),
              ),
            ),
        ],
      );
    }
    return KeyedSubtree(
      key: const ValueKey('diner-logo-padrao'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('Diner', style: dinerScript(s(66), cor: corNome, sombras: sombraNome, altura: .95)),
            SizedBox(width: s(8)),
            Transform.rotate(
              angle: -6 * 3.14159265 / 180,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: s(10), vertical: s(4)),
                decoration: BoxDecoration(color: _t.text, borderRadius: BorderRadius.circular(s(10))),
                child: Text('58', style: _t.display(s(34), cor: _t.bg, altura: 1)),
              ),
            ),
          ]),
          SizedBox(height: s(4)),
          Text('BURGERS · SHAKES',
              maxLines: 1,
              style: _t.display(s(15), cor: invertido ? _t.bg : _t.muted).copyWith(letterSpacing: s(15) * .2)),
        ],
      ),
    );
  }
}

/// Botão pílula do topo (Voltar, Cancelar).
class DinerBotaoTopo extends StatelessWidget {
  const DinerBotaoTopo({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.onTap,
    this.contorno = false,
    this.invertido = false,
  });

  final String rotulo;
  final IconData icone;
  final VoidCallback onTap;

  /// Só contorno (Cancelar).
  final bool contorno;
  final bool invertido;

  @override
  Widget build(BuildContext context) {
    final tinta = invertido ? _t.bg : (contorno ? _t.muted : _t.text);
    final fundo = contorno ? const Color(0x00000000) : (invertido ? const Color(0x29FFF4E2) : _t.surface2);
    final borda = contorno ? (invertido ? const Color(0x73FFF4E2) : _t.line) : null;
    return _Pressionavel(
      onTap: onTap,
      child: Container(
        height: context.dz(72),
        padding: EdgeInsets.symmetric(horizontal: context.dz(26)),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(context.dz(999)),
          border: borda == null ? null : Border.all(color: borda, width: context.dz(2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: context.dz(30), color: tinta),
          SizedBox(width: context.dz(10)),
          Text(rotulo, style: _t.texto(context.dz(26), peso: FontWeight.w800, cor: tinta)),
        ]),
      ),
    );
  }
}

/// Topo das telas internas: logo, Voltar/Cancelar e as 4 etapas (padding 40/48/16).
class DinerTopo extends StatelessWidget {
  const DinerTopo({
    super.key,
    required this.etapa,
    this.mov = Movimento.parado,
    this.nomeLoja,
    this.logoUrl,
    this.onVoltar,
    this.onCancelar,
    this.invertido = false,
    this.paddingTopo = 40,
  });

  /// 0..3; nulo = sem barra de etapas.
  final int? etapa;
  final Movimento mov;
  final String? nomeLoja;
  final String? logoUrl;
  final VoidCallback? onVoltar;
  final VoidCallback? onCancelar;
  final bool invertido;
  final double paddingTopo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(paddingTopo), context.dz(48), context.dz(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DinerLogo(nomeLoja: nomeLoja, logoUrl: logoUrl, escala: .78, invertido: invertido),
              ),
            ),
          ),
          SizedBox(width: context.dz(16)),
          if (onVoltar != null)
            DinerBotaoTopo(
              key: const ValueKey('topo-voltar'),
              rotulo: 'Voltar',
              icone: Icons.chevron_left_rounded,
              onTap: onVoltar!,
              invertido: invertido,
            ),
          if (onVoltar != null && onCancelar != null) SizedBox(width: context.dz(12)),
          if (onCancelar != null)
            DinerBotaoTopo(
              key: const ValueKey('topo-cancelar'),
              rotulo: 'Cancelar',
              icone: Icons.close_rounded,
              onTap: onCancelar!,
              contorno: true,
              invertido: invertido,
            ),
        ]),
        if (etapa != null) ...[
          SizedBox(height: context.dz(26)),
          Etapas(
            atual: etapa!,
            tokens: invertido ? dinerTokensInvertidos : _t,
            mov: mov,
            corBarra: invertido ? _t.bg : _t.accent,
            corTrilho: invertido ? const Color(0x40FFF4E2) : _t.line,
          ),
        ],
      ]),
    );
  }
}

/// Visual de um botão pílula do Diner.
enum DinerEstilo { primario, mint, contorno, suave, invertido }

/// Botão pílula (docs/templates/05 §5): primário vermelho, `mint`, contorno, suave e o
/// invertido do descanso (fundo creme, texto vermelho). Nunito 800; desabilitado a 35 %.
class DinerBotao extends StatelessWidget {
  const DinerBotao({
    super.key,
    required this.rotulo,
    required this.onTap,
    this.estilo = DinerEstilo.primario,
    this.icone,
    this.iconeDepois,
    this.altura = 124,
    this.fonte = 34,
    this.expandir = false,
  });

  final String rotulo;

  /// Nulo = desabilitado.
  final VoidCallback? onTap;
  final DinerEstilo estilo;
  final IconData? icone;
  final IconData? iconeDepois;

  /// Em px de desenho.
  final double altura;
  final double fonte;
  final bool expandir;

  @override
  Widget build(BuildContext context) {
    final (fundo, tinta, borda) = switch (estilo) {
      DinerEstilo.primario => (_t.accent, _t.onAccent, null),
      DinerEstilo.mint => (_t.accent2, _t.onAccent2, null),
      DinerEstilo.contorno => (const Color(0x00000000), _t.text, _t.line2),
      DinerEstilo.suave => (_t.surface2, _t.text, null),
      DinerEstilo.invertido => (_t.bg, _t.accent, null),
    };
    final fs = context.dz(fonte);
    // Com largura limitada o rótulo encolhe com reticências; solto (numa Row), mede o texto.
    Widget conteudo(bool limitado) {
      final texto = Text(rotulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _t.texto(fs, peso: FontWeight.w800, cor: tinta, altura: 1));
      return Row(
        mainAxisSize: expandir && limitado ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icone != null) ...[
            Icon(icone, size: fs * 1.2, color: tinta),
            SizedBox(width: context.dz(16)),
          ],
          if (limitado) Flexible(child: texto) else texto,
          if (iconeDepois != null) ...[
            SizedBox(width: context.dz(16)),
            Icon(iconeDepois, size: fs * 1.05, color: tinta),
          ],
        ],
      );
    }

    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: _Pressionavel(
        onTap: onTap,
        child: LayoutBuilder(
            builder: (context, c) => Container(
                  height: context.dz(altura),
                  padding: EdgeInsets.symmetric(horizontal: context.dz(fonte >= 40 ? 44 : 34)),
                  decoration: BoxDecoration(
                    color: fundo,
                    borderRadius: BorderRadius.circular(context.dz(999)),
                    border: borda == null ? null : Border.all(color: borda, width: context.dz(3)),
                  ),
                  // Sem `expandir`, o botão tem a largura do rótulo (mesmo numa Wrap/Column).
                  child: Align(
                    widthFactor: expandir && c.hasBoundedWidth ? null : 1,
                    child: conteudo(c.hasBoundedWidth),
                  ),
                )),
      ),
    );
  }
}

/// Toque com o "afundar" de 0,97 do protótipo (150 ms). Sem [onTap], não reage.
class _Pressionavel extends StatefulWidget {
  const _Pressionavel({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_Pressionavel> createState() => _PressionavelState();
}

class _PressionavelState extends State<_Pressionavel> {
  bool _baixo = false;

  void _marca(bool v) {
    if (_baixo != v && mounted) setState(() => _baixo = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return IgnorePointer(child: widget.child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _marca(true),
      onTapUp: (_) => _marca(false),
      onTapCancel: () => _marca(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _baixo ? .97 : 1,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}

/// Qualquer área tocável do Diner com o mesmo "afundar" dos botões.
class DinerToque extends StatelessWidget {
  const DinerToque({super.key, required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Pressionavel(onTap: onTap, child: child);
}

/// Botão redondo "+" (76 de desenho): marrom no cardápio, vermelho nas sugestões.
class DinerMais extends StatelessWidget {
  const DinerMais({
    super.key,
    required this.onTap,
    this.diametro = 76,
    this.fundo,
    this.tinta,
    this.feito = false,
  });

  final VoidCallback? onTap;
  final double diametro;
  final Color? fundo;
  final Color? tinta;

  /// Já adicionado: mostra ✓.
  final bool feito;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(diametro);
    return _Pressionavel(
      onTap: onTap,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: fundo ?? _t.accent, shape: BoxShape.circle),
        child: Icon(feito ? Icons.check_rounded : Icons.add_rounded, size: d * .52, color: tinta ?? _t.onAccent),
      ),
    );
  }
}

/// Caixa com borda tracejada vermelha de 4 (especial do dia, sugestões, senha).
class CaixaTracejada extends StatelessWidget {
  const CaixaTracejada({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.raio = 30,
    this.fundo = const Color(0xFFFFFFFF),
    this.recortar = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Em px de desenho.
  final double raio;
  final Color fundo;

  /// Recorta o conteúdo no raio (foto encostada na borda).
  final bool recortar;

  @override
  Widget build(BuildContext context) {
    final r = context.dz(raio);
    final corpo = DecoratedBox(
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(r)),
      child: Padding(padding: padding, child: child),
    );
    return CustomPaint(
      foregroundPainter: TracejadoPainter(cor: _t.accent, espessura: context.dz(4), raio: r),
      child: recortar ? ClipRRect(borderRadius: BorderRadius.circular(r), child: corpo) : corpo,
    );
  }
}

/// Selo de preço inclinado (−3°): fundo vermelho, Bungee creme. Ao adicionar, dá uma volta
/// inteira (500 ms) — [giros] conta as voltas; sem movimento, fica parado.
class SeloPreco extends StatelessWidget {
  const SeloPreco({
    super.key,
    required this.texto,
    this.fonte = 28,
    this.giros = 0,
    this.mov = Movimento.parado,
    this.inclinacao = -3,
    this.fundo,
    this.tinta,
  });

  final String texto;
  final double fonte;
  final int giros;
  final Movimento mov;
  final double inclinacao;
  final Color? fundo;
  final Color? tinta;

  @override
  Widget build(BuildContext context) {
    final base = inclinacao * 3.14159265 / 180;
    final selo = Container(
      padding: EdgeInsets.symmetric(horizontal: context.dz(18), vertical: context.dz(10)),
      decoration: BoxDecoration(color: fundo ?? _t.accent, borderRadius: BorderRadius.circular(context.dz(14))),
      child: Text(texto, maxLines: 1, style: _t.display(context.dz(fonte), cor: tinta ?? _t.bg, altura: 1.1)),
    );
    if (giros == 0 || !mov.anima || !mov.particulas) {
      return Transform.rotate(angle: base, child: selo);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('giro-$giros'),
      tween: Tween(begin: 0, end: 1),
      duration: mov.d(500),
      curve: Curves.easeInOutCubic,
      child: selo,
      builder: (_, v, filho) => Transform.rotate(angle: base + v * 2 * 3.14159265, child: filho),
    );
  }
}

/// Fileira de lâmpadas em perseguição (cabeçalho do cardápio: 18 de 16 px). Um controller,
/// um painter; sem partículas, todas acesas e paradas.
class FileiraLampadas extends StatefulWidget {
  const FileiraLampadas({super.key, required this.quantidade, required this.diametro, required this.mov});
  final int quantidade;

  /// Em px de desenho.
  final double diametro;
  final Movimento mov;

  @override
  State<FileiraLampadas> createState() => _FileiraLampadasState();
}

class _FileiraLampadasState extends State<FileiraLampadas> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  List<Lampada> _pontos = const [];
  Size? _tamanho;

  bool get _persegue => widget.mov.anima && widget.mov.particulas;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    if (_persegue) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<Lampada> _calcula(Size s, double r) {
    if (_tamanho == s) return _pontos;
    _tamanho = s;
    final n = widget.quantidade;
    final passo = n > 1 ? (s.width - 2 * r) / (n - 1) : 0.0;
    _pontos = List.unmodifiable([for (var i = 0; i < n; i++) Lampada(Offset(r + i * passo, s.height / 2), i)]);
    return _pontos;
  }

  @override
  Widget build(BuildContext context) {
    final d = context.dz(widget.diametro);
    return RepaintBoundary(
      child: SizedBox(
        height: d * 1.8,
        child: LayoutBuilder(builder: (_, c) {
          final s = Size(c.maxWidth, d * 1.8);
          return CustomPaint(
            size: s,
            painter: LampadasPainter(
              pontos: _calcula(s, d / 2),
              raio: d / 2,
              brilho: widget.mov.blur,
              t: _persegue ? _c : null,
            ),
          );
        }),
      ),
    );
  }
}

/// Foto do produto no Diner: a mesma regra do `ProdutoArte` comum (`.png` = recorte com
/// sombra, o resto = foto cobrindo, sem URL = placeholder), mas com placeholder CLARO — o
/// do `ProdutoImagem` é escuro (marca GoGeM) e fica um buraco preto no creme enquanto a
/// foto baixa ou quando ela falha. Imagem em memória no tamanho exibido.
class DinerArte extends StatelessWidget {
  const DinerArte({
    super.key,
    required this.url,
    this.raio = 0,
    this.escalaRecorte = .86,
    this.fundo,
    this.circulo = false,
  });

  final String? url;

  /// Em px de TELA.
  final double raio;
  final double escalaRecorte;
  final Color? fundo;
  final bool circulo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final largura = c.maxWidth.isFinite ? c.maxWidth : 400.0;
      final cache = (largura * dpr).round().clamp(64, 1400);
      final corFundo = fundo ?? _t.art;
      final vazio = _Vazio(fundo: corFundo);
      Widget arte;
      final u = url;
      if (u == null || u.isEmpty) {
        arte = vazio;
      } else if (!ProdutoArte.ehRecorte(u)) {
        arte = ColoredBox(
          color: corFundo,
          child: CachedNetworkImage(
            imageUrl: u,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: cache,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (_, __) => _Vazio(fundo: corFundo, carregando: true),
            errorWidget: (_, __, ___) => vazio,
          ),
        );
      } else {
        arte = ColoredBox(
          color: corFundo,
          child: FractionallySizedBox(
            widthFactor: escalaRecorte,
            heightFactor: escalaRecorte,
            child: CachedNetworkImage(
              imageUrl: u,
              fit: BoxFit.contain,
              memCacheWidth: (cache * escalaRecorte).round(),
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) => _Vazio(fundo: corFundo, carregando: true),
              errorWidget: (_, __, ___) => vazio,
            ),
          ),
        );
      }
      if (circulo) return ClipOval(child: arte);
      return ClipRRect(borderRadius: BorderRadius.circular(raio), child: arte);
    });
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.fundo, this.carregando = false});
  final Color fundo;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: fundo,
      child: LayoutBuilder(builder: (_, c) {
        final lado = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 120.0;
        return Center(
          child: carregando
              ? SizedBox(
                  width: lado * .2,
                  height: lado * .2,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: _t.accent.withAlpha(150)),
                )
              : Icon(Icons.lunch_dining_rounded, size: lado * .36, color: _t.line2),
        );
      }),
    );
  }
}

/// Véu escuro atrás dos cartões centrais (produto, peça também): o protótipo mostra a tela
/// de trás escurecida; aqui a rota é opaca, então o véu é desenhado — com a faixa vermelha
/// do cabeçalho quando o cartão abre por cima do cardápio.
class DinerVeu extends StatelessWidget {
  const DinerVeu({super.key, this.cabecalho = false, this.onTap});
  final bool cabecalho;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(children: [
        if (cabecalho) Container(height: context.dz(210), color: dinerVeuCabecalho),
        const Expanded(child: ColoredBox(color: dinerVeu, child: SizedBox.expand())),
      ]),
    );
  }
}

/// Texto de "kicker" (Último passo, Pix, Pagamento aprovado): 26, 800, espaçado, vermelho.
TextStyle dinerKicker(BuildContext context, {Color? cor}) => _t
    .texto(context.dz(26), peso: FontWeight.w800, cor: cor ?? _t.accent)
    .copyWith(letterSpacing: context.dz(26) * .12);

/// Rótulo de seção (ACOMPANHAMENTO, RESUMO DO PEDIDO): 23, 800, espaçado, `muted`.
TextStyle dinerRotulo(BuildContext context) =>
    _t.texto(context.dz(23), peso: FontWeight.w800, cor: _t.muted).copyWith(letterSpacing: context.dz(23) * .1);
