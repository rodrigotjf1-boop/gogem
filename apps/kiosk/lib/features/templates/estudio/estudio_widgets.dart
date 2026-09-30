import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../comum/etapas.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../movimento.dart';
import 'estudio_tokens.dart';

const _t = estudioTokens;

// ─────────────────────────────────────────────────────────────── tela e entrada

/// Moldura de toda tela do Estúdio: tema CLARO (o do app é escuro), fundo `bg`, área
/// segura e a entrada padrão (550 ms, vindo 90 px da direita + fade — docs/03 §7).
class TelaEstudio extends StatelessWidget {
  const TelaEstudio({
    super.key,
    required this.child,
    this.mov = Movimento.parado,
    this.entrada = true,
    this.fundo,
  });

  final Widget child;
  final Movimento mov;

  /// `false` quando a tela tem entrada própria (produto girando, cartão central).
  final bool entrada;
  final Color? fundo;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: temaEstudio,
      child: Scaffold(
        backgroundColor: fundo ?? _t.bg,
        body: SafeArea(child: entrada ? EntradaTela(mov: mov, child: child) : child),
      ),
    );
  }
}

/// Entrada da direita (+90 px) com fade, 550 ms. Sem animação, aparece direto.
/// A árvore é sempre a mesma (fade + translação), para o estado dos filhos não se perder
/// quando a entrada termina.
class EntradaTela extends StatefulWidget {
  const EntradaTela({super.key, required this.mov, required this.child});
  final Movimento mov;
  final Widget child;

  @override
  State<EntradaTela> createState() => _EntradaTelaState();
}

class _EntradaTelaState extends State<EntradaTela> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _v;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(550));
    _v = CurvedAnimation(parent: _c, curve: curvaTela);
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
    final dx = context.dz(90);
    return FadeTransition(
      opacity: _v,
      child: AnimatedBuilder(
        animation: _v,
        builder: (_, child) => Transform.translate(offset: Offset(dx * (1 - _v.value), 0), child: child),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── aparência da loja

/// Lê a aparência da loja (nome, logo) quando há um `ProviderScope` acima — as Views de
/// props (identificação, pagamento, sucesso) não recebem o nome da loja. Sem escopo (teste
/// de View isolada), entrega `null` e o template usa o logo padrão.
class ComAparencia extends StatelessWidget {
  const ComAparencia({super.key, required this.builder});
  final Widget Function(BuildContext context, Aparencia? ap) builder;

  @override
  Widget build(BuildContext context) {
    final temEscopo = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
    if (!temEscopo) return builder(context, null);
    return Consumer(
      builder: (context, ref, _) => builder(context, ref.watch(aparenciaProvider).valueOrNull),
    );
  }
}

// ─────────────────────────────────────────────────────────────── logo

/// Logo do Estúdio: a imagem da loja (`logoUrl`) ou dois círculos (acento e amarelo) com
/// o nome da loja em Sora 800. Sem nome nem logo, o logo padrão do template ("forma ·
/// burger studio", docs/03 §4). [escala] multiplica as medidas de desenho.
class LogoEstudio extends StatelessWidget {
  const LogoEstudio({super.key, this.escala = 1, this.nomeLoja, this.logoUrl});

  final double escala;
  final String? nomeLoja;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final s = escala;
    final logo = logoUrl?.trim() ?? '';
    if (logo.isNotEmpty) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return SizedBox(
        key: const ValueKey('logo-loja'),
        height: context.dz(72 * s),
        width: context.dz(320 * s),
        child: ImagemEstudio(
          url: logo,
          fit: BoxFit.contain,
          alinhamento: Alignment.centerLeft,
          memCacheWidth: (context.dz(320 * s) * dpr).round(),
        ),
      );
    }
    final nome = nomeLoja?.trim() ?? '';
    final padrao = nome.isEmpty;
    final bola = context.dz(46 * s);
    return Row(
      key: const ValueKey('logo-estudio'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: bola + context.dz(18 * s),
          height: bola,
          child: Stack(children: [
            Positioned(left: context.dz(18 * s), child: _Bola(d: bola, cor: _t.accent2)),
            Positioned(left: 0, child: _Bola(d: bola, cor: _t.accent)),
          ]),
        ),
        SizedBox(width: context.dz(16 * s)),
        Flexible(
          child: Text(
            padrao ? 'forma' : nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _t.display(context.dz(52 * s), altura: 1).copyWith(letterSpacing: context.dz(-2.1 * s)),
          ),
        ),
        if (padrao) ...[
          SizedBox(width: context.dz(14 * s)),
          Padding(
            padding: EdgeInsets.only(top: context.dz(14 * s)),
            child: Text('burger studio',
                style: _t.texto(context.dz(20 * s), peso: FontWeight.w600, cor: _t.muted)),
          ),
        ],
      ],
    );
  }
}

class _Bola extends StatelessWidget {
  const _Bola({required this.d, required this.cor});
  final double d;
  final Color cor;
  @override
  Widget build(BuildContext context) =>
      Container(width: d, height: d, decoration: BoxDecoration(color: cor, shape: BoxShape.circle));
}

/// Logo com o nome/logo da loja lidos da aparência (quando houver escopo).
class LogoDaLoja extends StatelessWidget {
  const LogoDaLoja({super.key, this.escala = .78});
  final double escala;

  @override
  Widget build(BuildContext context) => ComAparencia(
        builder: (_, ap) => LogoEstudio(escala: escala, nomeLoja: ap?.nomeLoja, logoUrl: ap?.logoUrl),
      );
}

// ─────────────────────────────────────────────────────────────── topo

/// Topo padrão das telas internas: logo, "Voltar"/"Cancelar" e as [Etapas] (§6.2).
class TopoEstudio extends StatelessWidget {
  const TopoEstudio({
    super.key,
    this.etapa,
    this.onVoltar,
    this.onCancelar,
    this.mov = Movimento.parado,
  });

  /// 0..3; nulo = sem a barra de etapas.
  final int? etapa;
  final VoidCallback? onVoltar;
  final VoidCallback? onCancelar;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(40), context.dz(48), context.dz(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Expanded(child: Align(alignment: Alignment.centerLeft, child: LogoDaLoja())),
          if (onVoltar != null)
            _BotaoTopo(
              chave: 'topo-voltar',
              icone: Icons.chevron_left_rounded,
              rotulo: 'Voltar',
              onTap: onVoltar!,
            ),
          if (onVoltar != null && onCancelar != null) SizedBox(width: context.dz(12)),
          if (onCancelar != null)
            _BotaoTopo(
              chave: 'topo-cancelar',
              icone: Icons.close_rounded,
              rotulo: 'Cancelar',
              contorno: true,
              onTap: onCancelar!,
            ),
        ]),
        if (etapa != null) ...[
          SizedBox(height: context.dz(26)),
          EtapasEstudio(atual: etapa!, mov: mov),
        ],
      ]),
    );
  }
}

/// Variante local das `Etapas` da base: o "✓" dos passos concluídos é um ÍCONE — Sora e
/// Figtree não têm o glifo U+2713 e ele sairia como uma caixa vazia (visto na captura).
/// Rótulos como no protótipo: 22, 600 `muted`; o atual em 800 `text`; os feitos no acento.
class EtapasEstudio extends StatelessWidget {
  const EtapasEstudio({super.key, required this.atual, this.mov = Movimento.parado});

  /// 0..3.
  final int atual;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final alto = context.dz(8);
    return Row(
      key: ValueKey('etapas-$atual'),
      children: [
        for (var i = 0; i < Etapas.nomes.length; i++) ...[
          if (i > 0) SizedBox(width: context.dz(14)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(alto),
                child: SizedBox(
                  height: alto,
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(color: _t.line),
                    if (i < atual)
                      ColoredBox(color: _t.accent)
                    else if (i == atual)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: mov.anima ? 0 : 1, end: 1),
                        duration: duracao(mov, 800),
                        curve: curvaTela,
                        builder: (_, v, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
                          child: ColoredBox(color: _t.accent),
                        ),
                      ),
                  ]),
                ),
              ),
              SizedBox(height: context.dz(10)),
              Row(children: [
                if (i < atual) ...[
                  Icon(Icons.check_rounded, size: context.dz(24), color: _t.accent),
                  SizedBox(width: context.dz(6)),
                ],
                Flexible(
                  child: Text(
                    i < atual ? Etapas.nomes[i] : '${i + 1}. ${Etapas.nomes[i]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t.texto(
                      context.dz(22),
                      peso: i == atual ? FontWeight.w800 : FontWeight.w600,
                      cor: i < atual ? _t.accent : (i == atual ? _t.text : _t.muted),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ],
    );
  }
}

class _BotaoTopo extends StatelessWidget {
  const _BotaoTopo({
    required this.chave,
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.contorno = false,
  });
  final String chave;
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  final bool contorno;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(context.dz(_t.raioBotao));
    return Material(
      color: contorno ? const Color(0x00000000) : _t.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: raio,
        side: contorno ? BorderSide(color: _t.line, width: context.dz(2)) : BorderSide.none,
      ),
      child: InkWell(
        key: ValueKey(chave),
        borderRadius: raio,
        onTap: onTap,
        child: SizedBox(
          height: context.dz(72),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.dz(26)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icone, size: context.dz(32), color: _t.text),
              SizedBox(width: context.dz(10)),
              Text(rotulo, style: _t.texto(context.dz(26), peso: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── botões

enum TipoBotao { primario, soft, contorno }

/// Botão do Estúdio (`.btn`): raio 28, primário no acento, `soft` em `surface2` e
/// contorno com borda `line2`. `onTap` nulo = desabilitado (35% de opacidade).
class BotaoEstudio extends StatelessWidget {
  const BotaoEstudio({
    super.key,
    required this.rotulo,
    required this.onTap,
    this.tipo = TipoBotao.primario,
    this.icone,
    this.iconeDepois,
    this.altura = 124,
    this.fonte = 34,
    this.chave,
    this.largura,
  });

  final String rotulo;
  final VoidCallback? onTap;
  final TipoBotao tipo;
  final IconData? icone;
  final IconData? iconeDepois;

  /// Altura e fonte em px de desenho (124/34 padrão; 170/40 no descanso).
  final double altura;
  final double fonte;

  /// Chave de teste (fica no `InkWell`).
  final String? chave;

  /// Largura em px de TELA (nulo = a do conteúdo, ou a que o pai impuser).
  final double? largura;

  @override
  Widget build(BuildContext context) {
    final (fundo, tinta, borda) = switch (tipo) {
      TipoBotao.primario => (_t.accent, _t.onAccent, null),
      TipoBotao.soft => (_t.surface2, _t.text, null),
      TipoBotao.contorno => (const Color(0x00000000), _t.text, _t.line2),
    };
    final raio = BorderRadius.circular(context.dz(_t.raioBotao));
    final tamIcone = context.dz(fonte * 1.15);
    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: Material(
        color: fundo,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: borda == null ? BorderSide.none : BorderSide(color: borda, width: context.dz(3)),
        ),
        child: InkWell(
          key: chave == null ? null : ValueKey<String>(chave!),
          borderRadius: raio,
          onTap: onTap,
          child: SizedBox(
            height: context.dz(altura),
            width: largura,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.dz(40)),
              child: Center(
                widthFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icone != null) ...[
                      Icon(icone, size: tamIcone, color: tinta),
                      SizedBox(width: context.dz(16)),
                    ],
                    Text(rotulo,
                        maxLines: 1,
                        style: _t.texto(context.dz(fonte), peso: FontWeight.w800, cor: tinta, altura: 1)),
                    if (iconeDepois != null) ...[
                      SizedBox(width: context.dz(16)),
                      Icon(iconeDepois, size: tamIcone, color: tinta),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão redondo "+" no acento (`.addb`). Diâmetro em px de desenho.
class BotaoMais extends StatelessWidget {
  const BotaoMais({super.key, required this.onTap, this.diametro = 76, this.chave, this.feito = false});
  final VoidCallback? onTap;
  final double diametro;
  final String? chave;

  /// Já adicionado: mostra ✓ no lugar do +.
  final bool feito;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(diametro);
    return Material(
      color: _t.accent,
      shape: const CircleBorder(),
      child: InkWell(
        key: chave == null ? null : ValueKey<String>(chave!),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: d,
          height: d,
          child: Icon(feito ? Icons.check_rounded : Icons.add_rounded, size: d * .56, color: _t.onAccent),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── imagens

/// Variante CLARA do `ProdutoImagem`: o placeholder dele é escuro (tema padrão do app) e
/// ficaria um quadrado "sujo" no Estúdio. Aqui, enquanto baixa, nada aparece (o disco ou o
/// fundo do template ficam à vista); sem foto ou com erro, um ícone discreto. A imagem
/// continua em cache de disco e em memória no tamanho exibido (`memCacheWidth`).
class ImagemEstudio extends StatelessWidget {
  const ImagemEstudio({
    super.key,
    required this.url,
    required this.memCacheWidth,
    this.fit = BoxFit.cover,
    this.alinhamento = Alignment.center,
  });

  final String? url;
  final int memCacheWidth;
  final BoxFit fit;
  final Alignment alinhamento;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return const _SemFoto();
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      alignment: alinhamento,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memCacheWidth.clamp(48, 1400),
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => const SizedBox.expand(),
      errorWidget: (_, __, ___) => const _SemFoto(),
    );
  }
}

class _SemFoto extends StatelessWidget {
  const _SemFoto();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: c.biggest.shortestSide.isFinite ? c.biggest.shortestSide * .34 : 40,
            color: _t.muted.withAlpha(90),
          ),
        ),
      );
}

/// Foto comum (não recortada) num círculo com borda branca e sombra (docs/03 §5).
class FotoCirculo extends StatelessWidget {
  const FotoCirculo({super.key, required this.url, required this.diametro, required this.borda});

  final String? url;

  /// Em px de TELA.
  final double diametro;
  final double borda;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EstudioCores.branco,
        boxShadow: [
          BoxShadow(
            color: const Color(0x330E1A2B),
            blurRadius: diametro * .12,
            offset: Offset(0, diametro * .06),
          ),
        ],
      ),
      padding: EdgeInsets.all(borda),
      child: ClipOval(
        child: ColoredBox(
          color: _t.art,
          child: ImagemEstudio(url: url, memCacheWidth: (diametro * dpr).round()),
        ),
      ),
    );
  }
}

/// A arte do produto no Estúdio (§5), dentro da caixa que o pai der:
/// - recorte `.png`: a imagem inteira (contain) "flutuando" sobre o disco;
/// - foto comum: círculo com borda branca sobre o disco;
/// - sem foto: o disco com um ícone discreto.
/// [levantado] é o "press" do card: a arte sobe 12 e cresce 6% (350 ms), o disco vai a 1,15.
class ArteEstudio extends StatelessWidget {
  const ArteEstudio({
    super.key,
    required this.url,
    this.corDisco,
    this.alfaDisco = 51,
    this.disco = .875,
    this.foto = .83,
    this.borda = 6,
    this.recorteLargura = .96,
    this.recorteAltura = .92,
    this.levantado = false,
    this.mov = Movimento.parado,
  });

  final String? url;

  /// Nulo = sem disco.
  final Color? corDisco;

  /// Opacidade do disco (51 = 20%).
  final int alfaDisco;

  /// Diâmetro do disco e da foto como fração do menor lado da caixa.
  final double disco;
  final double foto;

  /// Borda branca da foto em px de desenho.
  final double borda;

  /// Tamanho máximo do recorte como fração da caixa.
  final double recorteLargura;
  final double recorteAltura;
  final bool levantado;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
      final h = c.maxHeight.isFinite ? c.maxHeight : w;
      final lado = math.min(w, h);
      final u = url?.trim() ?? '';
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final Widget conteudo;
      if (u.isEmpty) {
        conteudo = Icon(Icons.restaurant_menu_rounded, size: lado * .3, color: _t.muted.withAlpha(110));
      } else if (ProdutoArte.ehRecorte(u)) {
        conteudo = SizedBox(
          width: w * recorteLargura,
          height: h * recorteAltura,
          child: ImagemEstudio(
            url: u,
            fit: BoxFit.contain,
            memCacheWidth: (w * recorteLargura * dpr).round(),
          ),
        );
      } else {
        conteudo = FotoCirculo(url: u, diametro: lado * foto, borda: borda * k);
      }
      final d = lado * disco;
      final dur = duracao(mov, 350);
      return Stack(alignment: Alignment.center, children: [
        if (corDisco != null)
          AnimatedScale(
            scale: levantado ? 1.15 : 1,
            duration: duracao(mov, 400),
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(shape: BoxShape.circle, color: corDisco!.withAlpha(alfaDisco)),
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: levantado ? 1 : 0),
          duration: dur,
          curve: curvaEstudio,
          builder: (_, v, child) => Transform.translate(
            offset: Offset(0, -12 * k * v),
            child: Transform.scale(scale: 1 + .06 * v, child: child),
          ),
          child: conteudo,
        ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────── flutuação

/// Uma animação de flutuação (±18 px em 3,4 s, `easeInOut`) COMPARTILHADA por tela:
/// um só controller para o palco, os destaques e o recorte do produto (docs/03 §7).
/// Só roda com [ligada] (movimento cheio); senão, tudo fica parado.
class Flutuacao extends StatefulWidget {
  const Flutuacao({super.key, required this.ligada, required this.child});
  final bool ligada;
  final Widget child;

  /// A animação da tela (0 → 1 → 0), ou nulo quando está parada.
  static Animation<double>? de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EscopoFlutuacao>()?.animacao;

  @override
  State<Flutuacao> createState() => _FlutuacaoState();
}

class _FlutuacaoState extends State<Flutuacao> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _v;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
    _v = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    if (widget.ligada) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Flutuacao old) {
    super.didUpdateWidget(old);
    if (widget.ligada && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.ligada && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _EscopoFlutuacao(animacao: widget.ligada ? _v : null, child: widget.child);
}

class _EscopoFlutuacao extends InheritedWidget {
  const _EscopoFlutuacao({required this.animacao, required super.child});
  final Animation<double>? animacao;
  @override
  bool updateShouldNotify(_EscopoFlutuacao old) => old.animacao != animacao;
}

/// Faz o filho flutuar com a [Flutuacao] da tela. [amplitude] em px de desenho.
/// `respira`: em vez de subir, encolhe para 0,8 e esmaece para 0,6 no topo (a sombra).
class Flutua extends StatelessWidget {
  const Flutua({super.key, required this.child, this.amplitude = 18, this.respira = false});
  final Widget child;
  final double amplitude;
  final bool respira;

  @override
  Widget build(BuildContext context) {
    final a = Flutuacao.de(context);
    if (a == null) return child;
    final dy = context.dz(amplitude);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: a,
        builder: (_, filho) => respira
            ? Opacity(
                opacity: 1 - .4 * a.value,
                child: Transform.scale(scale: 1 - .2 * a.value, child: filho),
              )
            : Transform.translate(offset: Offset(0, -dy * a.value), child: filho),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── inclinação 3D

/// Card que inclina em 3D sob o dedo (docs/03 §8) e "afunda" no toque.
/// [inclina] só no movimento cheio; senão, só o press. O toque em si fica com os
/// `GestureDetector`/`InkWell` de dentro — o `Listener` não disputa o gesto.
class CartaoInclinavel extends StatefulWidget {
  const CartaoInclinavel({super.key, required this.inclina, required this.builder});

  final bool inclina;
  final Widget Function(BuildContext context, bool premido) builder;

  @override
  State<CartaoInclinavel> createState() => _CartaoInclinavelState();
}

class _CartaoInclinavelState extends State<CartaoInclinavel> {
  Offset _d = Offset.zero; // -0,5..0,5
  bool _premido = false;

  void _mover(PointerEvent e) {
    if (!widget.inclina) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final p = box.globalToLocal(e.position);
    setState(() => _d = Offset(
          (p.dx / box.size.width - .5).clamp(-.5, .5),
          (p.dy / box.size.height - .5).clamp(-.5, .5),
        ));
  }

  void _soltar(PointerEvent _) => setState(() {
        _d = Offset.zero;
        _premido = false;
      });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        setState(() => _premido = true);
        _mover(e);
      },
      onPointerMove: _mover,
      onPointerUp: _soltar,
      onPointerCancel: _soltar,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(begin: Offset.zero, end: _d),
        duration: widget.inclina ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOut,
        builder: (_, d, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0011)
            ..rotateX(-d.dy * 10 * math.pi / 180)
            ..rotateY(d.dx * 12 * math.pi / 180),
          child: child,
        ),
        child: widget.builder(context, _premido),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── textos

/// Título de tela (`h1`): Sora 800 84, espaçamento −0,04 em.
class TituloTela extends StatelessWidget {
  const TituloTela(this.texto, {super.key, this.centro = false, this.tamanho = 84});
  final String texto;
  final bool centro;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        textAlign: centro ? TextAlign.center : TextAlign.start,
        style: _t.display(context.dz(tamanho), altura: 1).copyWith(letterSpacing: context.dz(-.04 * tamanho)),
      );
}

/// Linha fina acima do título ("Último passo", "Pix"): 26, 800, caixa alta, no acento.
class Kicker extends StatelessWidget {
  const Kicker(this.texto, {super.key, this.icone, this.cor});
  final String texto;
  final IconData? icone;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? _t.accent;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icone != null) ...[
        Icon(icone, size: context.dz(32), color: c),
        SizedBox(width: context.dz(10)),
      ],
      Flexible(
        child: Text(texto.toUpperCase(),
            style: _t.texto(context.dz(26), peso: FontWeight.w800, cor: c, espaco: context.dz(26 * .12))),
      ),
    ]);
  }
}

/// Subtítulo (`.sub`): 32, `muted`, altura 1,4.
class Subtitulo extends StatelessWidget {
  const Subtitulo(this.texto, {super.key, this.centro = false});
  final String texto;
  final bool centro;
  @override
  Widget build(BuildContext context) => Text(
        texto,
        textAlign: centro ? TextAlign.center : TextAlign.start,
        style: _t.texto(context.dz(32), peso: FontWeight.w400, cor: _t.muted, altura: 1.4),
      );
}

/// Rodapé fixo das telas internas (`.foot`): linha em cima e margens do protótipo.
class RodapeEstudio extends StatelessWidget {
  const RodapeEstudio({super.key, required this.child, this.linha = true});
  final Widget child;
  final bool linha;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: linha ? Border(top: BorderSide(color: _t.line, width: context.dz(2))) : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
          child: child,
        ),
      );
}

/// Corpo rolável que empurra o [fim] para baixo quando sobra altura e rola quando falta
/// (telas baixas: harness de teste 800×600 e totem em paisagem).
class CorpoEstudio extends StatelessWidget {
  const CorpoEstudio({super.key, required this.inicio, this.fim, this.centro = false});
  final List<Widget> inicio;
  final Widget? fim;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30));
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, c.maxHeight - pad.vertical)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: centro ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: centro ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
                children: inicio,
              ),
              if (fim != null) ...[SizedBox(height: context.dz(26)), fim!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio/de espera no visual do Estúdio (cardápio carregando, sem snapshot…).
class EstadoEstudio extends StatelessWidget {
  const EstadoEstudio({
    super.key,
    this.titulo,
    this.detalhe,
    this.icone = Icons.restaurant_menu_rounded,
    this.acao,
    this.carregando = false,
    this.mov = Movimento.parado,
  });

  final String? titulo;
  final String? detalhe;
  final IconData icone;
  final Widget? acao;
  final bool carregando;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(150);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(color: _t.surface2, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: carregando && mov.anima
                ? SizedBox(
                    width: d * .45,
                    height: d * .45,
                    child: CircularProgressIndicator(color: _t.accent, strokeWidth: context.dz(7)),
                  )
                : Icon(carregando ? Icons.hourglass_top_rounded : icone, size: d * .46, color: _t.accent),
          ),
          if (titulo != null) ...[
            SizedBox(height: context.dz(30)),
            Text(titulo!,
                textAlign: TextAlign.center,
                style: _t.display(context.dz(46), altura: 1.1).copyWith(letterSpacing: context.dz(-1.2))),
          ],
          if (detalhe != null) ...[
            SizedBox(height: context.dz(14)),
            Text(detalhe!,
                textAlign: TextAlign.center,
                style: _t.texto(context.dz(28), peso: FontWeight.w400, cor: _t.muted, altura: 1.35)),
          ],
          if (acao != null) ...[SizedBox(height: context.dz(36)), acao!],
        ]),
      ),
    );
  }
}
