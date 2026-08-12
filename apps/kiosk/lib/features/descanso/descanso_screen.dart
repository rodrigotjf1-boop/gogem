import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/hardware/hardware_profile.dart';
import '../../printing/printer_providers.dart';
import '../../core/theme/gogem_theme.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_sync.dart';
import '../../data/update/updater.dart';
import '../../widgets/gogem_robot.dart';
import '../gogen/gogen_standby.dart';

/// Throttle do auto-update: checa no máximo 1x a cada 3h (a tela de descanso
/// monta várias vezes ao dia; não queremos bater na API a cada retorno ao idle).
DateTime _ultimoCheckUpdate = DateTime.fromMillisecondsSinceEpoch(0);

/// Tela de descanso (atrator). Aparência POR LOJA (Fase 6): logo/nome, chamada,
/// preço-isca e — se configurado — carrossel de mídias da loja; senão, o robô
/// GoGeM. Respeita `animacoes` (off/reduzido) e o perfil de hardware.
/// 5 toques no canto superior esquerdo abrem o portão administrativo.
class DescansoScreen extends ConsumerStatefulWidget {
  const DescansoScreen({super.key});
  @override
  ConsumerState<DescansoScreen> createState() => _DescansoScreenState();
}

class _DescansoScreenState extends ConsumerState<DescansoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  int _adminTaps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerHealthProvider.notifier).iniciar();
      // Auto-update: na tela idle (ninguém pedindo), verifica se há APK novo e
      // instala. Throttle de 3h para não checar a cada retorno ao descanso.
      final agora = DateTime.now();
      if (agora.difference(_ultimoCheckUpdate) > const Duration(hours: 3)) {
        _ultimoCheckUpdate = agora;
        ref.read(updaterProvider).verificarEAtualizar();
      }
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _tapAdminCorner() {
    final now = DateTime.now();
    if (now.difference(_lastTap) > const Duration(seconds: 2)) _adminTaps = 0;
    _lastTap = now;
    if (++_adminTaps >= 5) {
      _adminTaps = 0;
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(hardwareCapsProvider);
    final saude = ref.watch(printerHealthProvider);
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final t = Theme.of(context).textTheme;
    final anima = !ap.semAnimacao;
    // PORTÃO 1 — descanso: sem papel/tampa/offline => totem fora de operação.
    final bloqueado = !saude.prontaParaVenda && saude.ultimaChecagem != null;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          if (d.localPosition.dx < 96 && d.localPosition.dy < 96) {
            _tapAdminCorner();
            return;
          }
          if (!bloqueado) context.go('/catalogo');
        },
        child: Stack(children: [
          // Template GoGen: atrator próprio (flame + brasas + ticker). Substitui
          // fundo+marca+chamada; os PORTÕES abaixo (near-end/bloqueado) seguem.
          if (ap.gogen)
            Positioned.fill(
              child: GogenStandby(
                nomeLoja: ap.nomeLoja,
                logoUrl: ap.logoUrl,
                chamada: ap.chamada,
                precoIsca: ap.precoIsca,
                anima: anima,
              ),
            )
          else ...[
            // Fundo: carrossel da loja OU o robô/branding padrão.
            if (ap.carrossel)
              _Carrossel(
                  midias: ap.descansoMidias,
                  intervalo: ap.descansoIntervaloSeg,
                  anima: anima,
                  brasa: ap.editorial,
                  corKicker: ap.corPrimaria)
            else
              _FundoRobo(idle: _idle, caps: caps, anima: anima),

            // Marca da loja no topo (logo ou nome).
            Positioned(
              top: 28, left: 0, right: 0,
              child: Center(child: _Marca(ap: ap, t: t)),
            ),

            // Chamada + isca + pulso na base.
            Positioned(
              left: 0, right: 0, bottom: 40,
              child: Column(children: [
                if (ap.precoIsca != null) _IscaTag(texto: ap.precoIsca!, cor: ap.corPrimaria),
                const SizedBox(height: 14),
                Text(ap.chamada,
                    textAlign: TextAlign.center,
                    style: t.displayLarge?.copyWith(fontSize: 46)),
                const SizedBox(height: 10),
                Text('rápido · sem fila · do seu jeito',
                    style: t.bodyMedium?.copyWith(fontSize: 20)),
                const SizedBox(height: 34),
                if (anima) const _PulseDot() else const SizedBox(height: 22),
              ]),
            ),

            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Center(
                child: Text('GoGeM · by DMS',
                    style: t.bodyMedium?.copyWith(color: GogemColors.inkDim, fontSize: 12)),
              ),
            ),
          ],

          if (saude.pertoDoFim && !bloqueado)
            Positioned(
              top: 20, right: 20,
              child: Container(
                key: const ValueKey('aviso-nearend'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: GogemColors.cheese),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('PAPEL ACABANDO',
                    style: TextStyle(fontFamily: 'Tektur', fontSize: 12, color: GogemColors.cheese)),
              ),
            ),

          if (bloqueado)
            Positioned.fill(
              child: Container(
                key: const ValueKey('fora-operacao'),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const GogemRobot(size: 220, blink: 0.1, paperExtent: 0),
                  const SizedBox(height: 28),
                  Text('TOTEM FORA DE OPERACAO',
                      style: t.headlineMedium?.copyWith(color: GogemColors.heat)),
                  const SizedBox(height: 8),
                  Text('motivo: ${saude.motivo}', style: t.bodyLarge),
                  const SizedBox(height: 4),
                  Text('por favor, dirija-se ao balcao', style: t.bodyMedium),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Marca da loja: logo (se houver) ou o nome em display; nada = vazio discreto.
class _Marca extends StatelessWidget {
  const _Marca({required this.ap, required this.t});
  final Aparencia ap;
  final TextTheme t;
  @override
  Widget build(BuildContext context) {
    if (ap.logoUrl != null) {
      return CachedNetworkImage(
        imageUrl: ap.logoUrl!,
        height: 84,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _nome(),
      );
    }
    return _nome();
  }

  Widget _nome() => Text(
        ap.nomeLoja ?? '',
        style: t.headlineMedium?.copyWith(color: Colors.white, fontSize: 26),
      );
}

class _IscaTag extends StatelessWidget {
  const _IscaTag({required this.texto, required this.cor});
  final String texto;
  final Color cor;
  @override
  Widget build(BuildContext context) {
    final onCor = cor.computeLuminance() > 0.5 ? const Color(0xFF1A1206) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(999)),
      child: Text(texto,
          style: TextStyle(fontFamily: 'Tektur', fontSize: 14, color: onCor)),
    );
  }
}

/// Fundo com o robô GoGeM (flutuação + piscada), respeitando animação/hardware.
class _FundoRobo extends StatelessWidget {
  const _FundoRobo({required this.idle, required this.caps, required this.anima});
  final AnimationController idle;
  final HardwareCaps caps;
  final bool anima;
  @override
  Widget build(BuildContext context) {
    if (!anima) {
      return const Center(child: GogemRobot(size: 300, blink: 1));
    }
    return Center(
      child: AnimatedBuilder(
        animation: idle,
        builder: (_, __) {
          final v = idle.value;
          final dy = caps.animationScale * -12 * (0.5 - (v - 0.5).abs()) * 2;
          double blink = 1;
          for (final c in [0.55, 0.63]) {
            final d = (v - c).abs();
            if (d < 0.03) blink = (d / 0.03).clamp(0.1, 1.0);
          }
          return Transform.translate(
            offset: Offset(0, dy),
            child: GogemRobot(size: 300, blink: blink),
          );
        },
      ),
    );
  }
}

/// Carrossel de mídias da loja (imagens/gifs) com auto-avanço + escurecimento
/// para os textos ficarem legíveis por cima.
class _Carrossel extends StatefulWidget {
  const _Carrossel({
    required this.midias,
    required this.intervalo,
    required this.anima,
    required this.brasa,
    required this.corKicker,
  });
  final List<DescansoMidia> midias;
  final int intervalo;
  final bool anima;
  final bool brasa;
  final Color corKicker;
  @override
  State<_Carrossel> createState() => _CarrosselState();
}

class _CarrosselState extends State<_Carrossel> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.midias.length > 1) {
      _t = Timer.periodic(Duration(seconds: widget.intervalo), (_) {
        if (mounted) setState(() => _i = (_i + 1) % widget.midias.length);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final midia = widget.midias[_i % widget.midias.length];
    // Preset "brasa": escurece mais embaixo (look editorial/steakhouse).
    final topAlpha = widget.brasa ? 0.35 : 0.25;
    final bottomAlpha = widget.brasa ? 0.9 : 0.75;
    return Positioned.fill(
      child: Stack(fit: StackFit.expand, children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: widget.anima ? 500 : 0),
          child: CachedNetworkImage(
            key: ValueKey(midia.url),
            imageUrl: midia.url,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        // Escurece de baixo p/ cima (legibilidade dos textos).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: topAlpha),
                Colors.black.withValues(alpha: bottomAlpha),
              ],
            ),
          ),
        ),
        // Legenda editorial do slide (F3): chapéu + título + subtítulo.
        if (midia.temLegenda)
          Positioned(
            left: 40,
            right: 40,
            bottom: 200,
            child: Column(
              key: const ValueKey('descanso-legenda'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (midia.kicker != null)
                  Text(midia.kicker!.toUpperCase(),
                      style: t.titleLarge?.copyWith(
                          color: widget.corKicker,
                          letterSpacing: 3,
                          fontSize: 22)),
                if (midia.titulo != null) ...[
                  const SizedBox(height: 6),
                  Text(midia.titulo!,
                      style: t.displayLarge?.copyWith(
                          color: Colors.white, fontSize: 54, height: 1.0)),
                ],
                if (midia.subtitulo != null) ...[
                  const SizedBox(height: 6),
                  Text(midia.subtitulo!,
                      style: t.bodyLarge
                          ?.copyWith(color: Colors.white70, fontSize: 22)),
                ],
              ],
            ),
          ),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 22 + 10 * _c.value,
          height: 22 + 10 * _c.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GogemColors.mint.withAlpha((255 * (1 - _c.value * .8)).round()),
          ),
        ),
      );
}
