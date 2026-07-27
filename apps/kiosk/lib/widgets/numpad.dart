import 'package:flutter/material.dart';
import '../core/theme/gogem_theme.dart';

/// Teclado numérico do totem (sem teclado do sistema).
class NumPad extends StatelessWidget {
  const NumPad({super.key, required this.onDigito, required this.onApagar});
  final void Function(String) onDigito;
  final VoidCallback onApagar;
  @override
  Widget build(BuildContext context) {
    Widget btn(String label, {VoidCallback? onTap, Key? key}) => Padding(
          padding: const EdgeInsets.all(6),
          child: FilledButton(
            key: key,
            style: FilledButton.styleFrom(
              backgroundColor: GogemColors.panel,
              foregroundColor: GogemColors.ink,
              minimumSize: const Size(90, 68),
            ),
            onPressed: onTap ?? () => onDigito(label),
            child: Text(label, style: const TextStyle(fontSize: 26)),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final row in const [['1','2','3'],['4','5','6'],['7','8','9']])
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final d in row) btn(d, key: ValueKey('num-$d'))
        ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        btn('⌫', key: const ValueKey('num-apagar'), onTap: onApagar),
        btn('0', key: const ValueKey('num-0')),
        const SizedBox(width: 102),
      ]),
    ]);
  }
}
