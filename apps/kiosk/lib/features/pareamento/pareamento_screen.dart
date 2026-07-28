import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/pareamento/device_token.dart';
import '../../core/theme/gogem_theme.dart';
import '../../data/api/gogem_api.dart';

/// Tela de pareamento do totem (1º boot). O operador cadastra o totem no painel
/// (Frota) e digita aqui o código de 6 dígitos → o app recebe e guarda o token
/// de dispositivo. Depois disso o totem opera sem depender de login.
class PareamentoScreen extends ConsumerStatefulWidget {
  const PareamentoScreen({super.key});
  @override
  ConsumerState<PareamentoScreen> createState() => _PareamentoScreenState();
}

class _PareamentoScreenState extends ConsumerState<PareamentoScreen> {
  final _controller = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parear() async {
    final codigo = _controller.text.trim();
    if (codigo.length != 6) {
      setState(() => _erro = 'Digite os 6 dígitos do código.');
      return;
    }
    setState(() {
      _erro = null;
      _enviando = true;
    });
    try {
      await ref.read(deviceTokenProvider.notifier).parear(codigo);
      if (mounted) context.go('/descanso');
    } on GogemApiException {
      if (mounted) {
        setState(() => _erro = 'Código inválido ou expirado. Gere outro no painel.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Sem conexão com o servidor. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('PAREAR TOTEM', style: t.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Cadastre este totem no painel (Frota) e digite o código de 6 dígitos.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: GogemColors.inkDim),
                ),
                const SizedBox(height: 32),
                TextField(
                  key: const ValueKey('campo-codigo'),
                  controller: _controller,
                  autofocus: true,
                  enabled: !_enviando,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                      fontFamily: 'Tektur', fontSize: 40, letterSpacing: 12),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                  ),
                  onSubmitted: (_) => _parear(),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(_erro!,
                      key: const ValueKey('erro-pareamento'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: GogemColors.heat)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('acao-parear'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64)),
                  onPressed: _enviando ? null : _parear,
                  child: _enviando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('PAREAR', style: TextStyle(fontSize: 20)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
