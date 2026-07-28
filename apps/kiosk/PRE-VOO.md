# Pré-voo do kiosk — gate obrigatório antes de qualquer PR

O Fable (chat) gera o código SEM SDK Flutter no ambiente; a validação executável
é responsabilidade deste gate, rodado na máquina local/Claude Code:

```bash
cd apps/kiosk
flutter --version           # stable atual
flutter pub get
flutter analyze --fatal-infos
flutter test
```

Regras aprendidas (não repetir):
1. **APIs de cor:** nunca `withOpacity` (deprecado no stable novo) nem
   `withValues` (inexistente em stables antigos). Usar `withAlpha(...)` para
   alfa dinâmico e `Color(0xAARRGGBB)` const para alfa fixo.
2. **pumpAndSettle é PROIBIDO** em qualquer teste com a tela de descanso (ou
   outro widget com `AnimationController.repeat`/spinner infinito) na árvore —
   usar `tester.pump(Duration(...))` em passos fixos.
3. **Viewport do harness é 800x600:** taps por coordenada devem caber nele;
   preferir `tester.tap(find...)` a `tapAt` sempre que possível.
4. Qualquer warning novo do analyze = corrigir antes do PR, não suprimir.
5. **`.fold(0, ...)` é PROIBIDO** — sempre `.fold<int>(0, ...)` (o analyzer
   estrito infere `num` e quebra na atribuição a `int`).
6. **Teste com SQLite ffi: NUNCA `inMemoryDatabasePath` direto** — ele
   compartilha a mesma base entre testes (estado vaza, contagens acumulam).
   Usar `novaDbMemoria()` de `test/db_helper.dart` (path único por teste).
7. **Assert de bytes ESC/POS: nunca filtrar por `c >= 0x20`** — parâmetros de
   comandos (ESC @, ESC t, ESC a) são imprimíveis e contaminam a saída. Usar
   `String.fromCharCodes(bytes)` + `contains(sequência exata)`.
