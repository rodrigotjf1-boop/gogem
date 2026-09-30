import '../../core/hardware/hardware_profile.dart';
import '../../data/catalog/aparencia.dart';

/// O quanto um template pode se mexer, resolvido UMA vez por tela a partir da aparência
/// (`animacoes` do painel) e do perfil de hardware (docs/templates/00 §3.4).
///
/// Regras que todo template segue:
/// 1. `anima == false`: nenhum `AnimationController.repeat()` — mostra o quadro final.
/// 2. `particulas == false`: sem brasas, confete, faixas correndo ou lâmpadas piscando.
/// 3. `blur == false`: nada de `BackdropFilter` (vidro fosco vira cor sólida translúcida).
/// O Tinker Board (perfil `low`) não tem blur nem partículas e anima a 60% (ERR-018).
class Movimento {
  const Movimento({
    this.anima = true,
    this.particulas = true,
    this.blur = true,
    this.escala = 1.0,
  });

  /// Tudo parado: testes e `animacoes: off`.
  static const parado =
      Movimento(anima: false, particulas: false, blur: false, escala: 1.0);

  factory Movimento.de(Aparencia ap, HardwareCaps hw) {
    if (ap.semAnimacao) {
      return Movimento(anima: false, particulas: false, blur: hw.enableBlur, escala: 1.0);
    }
    final caps = ap.animacaoReduzida ? hw.reduzidas : hw;
    return Movimento(
      anima: true,
      particulas: caps.enableParticles,
      blur: caps.enableBlur,
      escala: caps.animationScale <= 0 ? 1.0 : caps.animationScale,
    );
  }

  final bool anima;
  final bool particulas;
  final bool blur;

  /// 1.0 normal; 0.6 no perfil fraco ou em "reduzido".
  final double escala;

  /// Duração ajustada ao perfil: com escala 0.6 o movimento fica mais longo e mais calmo.
  Duration d(int ms) => Duration(milliseconds: (ms / escala).round());
}
