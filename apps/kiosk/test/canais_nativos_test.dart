import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/update/updater.dart';

/// ERR-050: o build copia `tool/*.kt` por cima do projeto Android. Canal que o
/// Dart chama e que não está lá falha só no totem, calado.
void main() {
  group('canais nativos que o APK leva', () {
    final kotlin = Directory('tool')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.kt'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    test('todo canal gogem/ do Dart existe no Kotlin copiado pelo build', () {
      final canais = RegExp(r"(?:Method|Event)Channel\('(gogem/[^']+)'\)")
          .allMatches(dart)
          .map((m) => m.group(1)!)
          .toSet();
      expect(canais, containsAll(<String>[
        'gogem/kiosk',
        'gogem/usb_printer',
        'gogem/updater',
        'gogem/tef',
      ]));
      for (final canal in canais) {
        expect(kotlin, contains(canal), reason: 'canal $canal fora do tool/');
      }
    });

    test('os métodos do atualizador, do TEF e do quiosque têm quem responda',
        () {
      for (final metodo in [
        'modoInstalacao',
        'installApk',
        'disponivel',
        'executar',
        'entrar',
        'sair',
      ]) {
        expect(kotlin, contains('"$metodo" ->'), reason: metodo);
      }
    });

    test('a confirmação do Android é tratada', () {
      expect(kotlin, contains('STATUS_PENDING_USER_ACTION'));
      expect(kotlin, contains('Intent.EXTRA_INTENT'));
    });
  });

  group('quando instalar', () {
    bool decide(ModoInstalacao modo, MomentoDaAtualizacao momento,
            {bool obrigatoria = false}) =>
        deveInstalarAgora(
            obrigatoria: obrigatoria, modo: modo, momento: momento);

    test('com confirmação: ao ligar e no painel, nunca no descanso', () {
      const m = ModoInstalacao.confirmacao;
      expect(decide(m, MomentoDaAtualizacao.abertura), isTrue);
      expect(decide(m, MomentoDaAtualizacao.painel), isTrue);
      expect(decide(m, MomentoDaAtualizacao.descanso), isFalse);
    });

    test('com confirmação: a obrigatória também sai no descanso', () {
      expect(
          decide(ModoInstalacao.confirmacao, MomentoDaAtualizacao.descanso,
              obrigatoria: true),
          isTrue);
    });

    test('silencioso: no descanso e no painel; ao ligar, só a obrigatória', () {
      const m = ModoInstalacao.silencioso;
      expect(decide(m, MomentoDaAtualizacao.descanso), isTrue);
      expect(decide(m, MomentoDaAtualizacao.painel), isTrue);
      expect(decide(m, MomentoDaAtualizacao.abertura), isFalse);
      expect(decide(m, MomentoDaAtualizacao.abertura, obrigatoria: true),
          isTrue);
    });

    test('sem permissão ou sem canal: nunca baixa', () {
      for (final m in [
        ModoInstalacao.semPermissao,
        ModoInstalacao.indisponivel,
      ]) {
        for (final momento in MomentoDaAtualizacao.values) {
          expect(decide(m, momento, obrigatoria: true), isFalse);
        }
      }
    });

    test('o valor do canal vira o modo', () {
      expect(modoInstalacaoDe('silencioso'), ModoInstalacao.silencioso);
      expect(modoInstalacaoDe('confirmacao'), ModoInstalacao.confirmacao);
      expect(modoInstalacaoDe('sem_permissao'), ModoInstalacao.semPermissao);
      expect(modoInstalacaoDe(null), ModoInstalacao.indisponivel);
      expect(modoInstalacaoDe('outro'), ModoInstalacao.indisponivel);
    });
  });
}
