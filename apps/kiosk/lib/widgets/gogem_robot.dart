import 'package:flutter/material.dart';
import '../core/theme/gogem_theme.dart';

/// O Robô-Totem GoGeM desenhado em vetor (CustomPainter) — idêntico à marca:
/// cabeça âmbar, tela-rosto, olhos menta, fenda da boca e cupom-sorriso.
/// [paperExtent] 0..1 controla o quanto do cupom está "impresso" (animável).
/// [blink] 0..1 (1 = olho aberto).
class GogemRobot extends StatelessWidget {
  const GogemRobot({super.key, this.size = 240, this.paperExtent = 1, this.blink = 1});
  final double size;
  final double paperExtent;
  final double blink;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _RobotPainter(paperExtent: paperExtent, blink: blink),
      );
}

class _RobotPainter extends CustomPainter {
  _RobotPainter({required this.paperExtent, required this.blink});
  final double paperExtent;
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x * s, y * s, w * s, h * s), Radius.circular(r * s));
    final p = Paint()..isAntiAlias = true;

    // orelhas
    p.color = GogemColors.cheeseDeep;
    canvas.drawRRect(rr(88, 178, 24, 72, 12), p);
    canvas.drawRRect(rr(400, 178, 24, 72, 12), p);
    // cabeça (gradiente âmbar)
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [GogemColors.cheeseLight, GogemColors.cheeseDeep],
    ).createShader(Rect.fromLTWH(112 * s, 84 * s, 288 * s, 260 * s));
    canvas.drawRRect(rr(112, 84, 288, 260, 52), p);
    p.shader = null;
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..color = GogemColors.cheeseGlow;
    canvas.drawRRect(rr(112, 84, 288, 260, 52), p);
    // tela-rosto
    p
      ..style = PaintingStyle.fill
      ..color = GogemColors.bg;
    canvas.drawRRect(rr(140, 112, 232, 176, 34), p);
    // olhos (blink escala a altura)
    final eh = (58 * blink).clamp(6, 58).toDouble();
    final ey = 166 + (58 - eh) / 2;
    p.color = GogemColors.mint;
    canvas.drawRRect(rr(178, ey, 36, eh, 17), p);
    canvas.drawRRect(rr(298, ey, 36, eh, 17), p);
    if (blink > 0.5) {
      p.color = Colors.white.withValues(alpha: .85);
      canvas.drawOval(Rect.fromLTWH(200 * s, (ey + 6) * s, 10 * s, 14 * s), p);
      canvas.drawOval(Rect.fromLTWH(320 * s, (ey + 6) * s, 10 * s, 14 * s), p);
    }
    // boca (fenda da impressora)
    p.color = GogemColors.bg;
    canvas.drawRRect(rr(206, 306, 100, 18, 8), p);
    // cupom-sorriso
    if (paperExtent > 0.02) {
      final bottom = 320 + 96 * paperExtent; // 320 -> 416
      final paper = Path()
        ..moveTo(214 * s, 320 * s)
        ..lineTo(298 * s, 320 * s)
        ..lineTo(298 * s, bottom * s);
      const teeth = 6;
      const w = 84 / teeth;
      for (var i = 0; i < teeth; i++) {
        paper
          ..lineTo((298 - w * (i + .5)) * s, (bottom + 12) * s)
          ..lineTo((298 - w * (i + 1)) * s, bottom * s);
      }
      paper.close();
      p.color = GogemColors.paper;
      canvas.drawPath(paper, p);
      // check de pedido confirmado
      if (paperExtent > 0.45) {
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * s
          ..color = GogemColors.mintDeep;
        canvas.drawCircle(Offset(241 * s, 344 * s), 13 * s, p);
        final check = Path()
          ..moveTo(234 * s, 344 * s)
          ..lineTo(240 * s, 350 * s)
          ..lineTo(249 * s, 337 * s);
        canvas.drawPath(check, p);
        p
          ..color = const Color(0xFFB9B4A0)
          ..strokeWidth = 5 * s;
        canvas.drawLine(Offset(264 * s, 338 * s), Offset(286 * s, 338 * s), p);
        canvas.drawLine(Offset(264 * s, 350 * s), Offset(276 * s, 350 * s), p);
      }
    }
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.paperExtent != paperExtent || old.blink != blink;
}
