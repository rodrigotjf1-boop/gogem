import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';

/// Placeholder da Fatia 3 — hoje só prova a navegação e o layout base.
class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                onPressed: () => context.go('/descanso'),
                icon: const Icon(Icons.arrow_back, color: GogemColors.ink, size: 32),
              ),
              const SizedBox(width: 8),
              Text('MONTE SEU PEDIDO', style: t.headlineMedium),
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Text(
                  'Catálogo chega na Fatia 2/3\n(sync do cardápio publicado + fluxo de pedido)',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
