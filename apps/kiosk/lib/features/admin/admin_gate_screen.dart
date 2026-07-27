import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';

/// Portão administrativo com teclado numérico EMBARALHADO (anti-observação),
/// paridade com o padrão do mercado. PIN de dev: 4590 (trocar por config
/// provisionada na fatia do kiosk-mode).
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key});
  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  /// PIN provisionado por dispositivo: --dart-define=GOGEM_ADMIN_PIN=xxxx
  static const _pinDev =
      String.fromEnvironment('GOGEM_ADMIN_PIN', defaultValue: '4590');
  late List<int> _keys;
  String _typed = '';

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() => _keys = List.generate(10, (i) => i)..shuffle(Random());

  void _press(int n) {
    setState(() {
      _typed += '$n';
      if (_typed.length >= _pinDev.length) {
        if (_typed == _pinDev) {
          _typed = '';
          context.go('/admin/painel');
          return;
        }
        _typed = '';
        _shuffle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 32),
          Text('ACESSO RESTRITO', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text('•' * _typed.length, style: t.displayLarge),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.symmetric(horizontal: 80),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                for (final n in _keys)
                  FilledButton(
                    key: ValueKey('k$n'),
                    style: FilledButton.styleFrom(backgroundColor: GogemColors.panel,
                        foregroundColor: GogemColors.ink),
                    onPressed: () => _press(n),
                    child: Text('$n', style: const TextStyle(fontSize: 30)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextButton(
              onPressed: () => context.go('/descanso'),
              child: const Text('VOLTAR', style: TextStyle(color: GogemColors.inkDim)),
            ),
          ),
        ]),
      ),
    );
  }
}
