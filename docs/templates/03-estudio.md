# 03 · Template **Estúdio** (`temaPreset: 'estudio'`)

> Pré-requisito: Fase 0 do `00-base-templates.md`. Medidas em px de desenho sobre 1080 de largura (`context.dz`).

## 1. Conceito

Um fundo claro de estúdio fotográfico, com os lanches recortados **flutuando** sobre discos de cor:
- Um carrossel gira os destaques trocando a cor do disco.
- Os cards inclinam levemente em 3D quando tocados, como num app de produto premium.
- **Referências:** Apple Store, Sweetgreen, apps de delivery premium.
- **Ideal para:** marcas modernas, almoço e público diurno. É o único template **claro** com visual "tech".

> Fica melhor com fotos **recortadas** (PNG sem fundo). Foto comum entra num círculo recortado com borda branca (seção 5). Veja também o item 3 da Fase B no 00.

## 2. Mockups de referência

`mockups/03-estudio/`. No protótipo, selecione **3. Estúdio**. No CSS, os seletores são `.t-estudio`, `.att-estudio`, `.menu-estudio`, `.ecard`, `.efeat`, `.pm-center`.

## 3. Tokens

```dart
const estudioTokens = TemplateTokens(
  bg: Color(0xFFEEF1F5),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFE2E7EF),
  text: Color(0xFF0E1A2B),        // azul-marinho quase preto
  muted: Color(0xFF56637A),
  accent: Color(0xFF2F55F4),      // azul elétrico
  onAccent: Color(0xFFFFFFFF),
  accent2: Color(0xFFFFC83D),     // amarelo
  onAccent2: Color(0xFF0E1A2B),
  line: Color(0xFFD7DEE8),
  line2: Color(0xFFAAB6C6),
  price: Color(0xFF0E1A2B),
  hi: Color(0xFFE6ECFF),
  art: Color(0xFFF1F4F8),
  ok: Color(0xFF1E9E5A),
  err: Color(0xFFD93A3A),
  raio: 38, raioBotao: 28, raioTecla: 26,
  fonteDisplay: 'Sora',
  fonteTexto: 'Figtree',
  pesoDisplay: FontWeight.w800,
  claro: true,
);
/// Cores de disco (rotação por índice ou pela `categoria.cor`):
const estudioDiscos = [Color(0xFF2F55F4), Color(0xFFFFC83D), Color(0xFFFF7A59), Color(0xFF7BC8A4)];
/// Sombra de card: [BoxShadow(0x0D0E1A2B, blur 2, y 1), BoxShadow(0x120E1A2B, blur 34, y 16)]
```

Como o template é claro, a `ThemeData` desta rota deve ter `brightness: Brightness.light` (ou os widgets do template devem definir cor de texto explicitamente). O tema global do app é dark.

## 4. Tipografia

| Uso | Fonte | Tamanho |
|---|---|---|
| H1 do descanso | Sora 800 | 132, altura 0,93, espaçamento −0,05 em; a 3ª linha em `accent` |
| Títulos de tela | Sora 800 | 84, espaçamento −0,04 em |
| Nome no destaque | Sora 800 | 62 |
| Título de seção | Sora 800 | 56 + contagem Figtree 600 26 `muted` |
| Nome no card | Figtree 800 | 30 |
| Corpo | Figtree 400–600 | 28–34 |
| Preço | Figtree 800 | 34 |

Logo padrão: dois círculos (46, `accent` e `accent2` deslocado 18 à direita), "forma" em Sora 800 52 e "burger studio" em Figtree 600 20 `muted`.

## 5. Componentes

- **Botões:** raio 28. Primário `accent`. `soft` com fundo `surface2`.
- **Card de produto (`.ecard`):**
  - Fundo branco, raio 36, padding 18/18/22 e sombra dupla (tokens).
  - Área da foto com 240 de altura e **disco** de 210 na cor do índice a 20% de opacidade (`withAlpha(51)`).
  - Recorte com no máximo 96%. No press, sobe 12 e escala 1,06 (350 ms `Cubic(.2,.9,.2,1)`), e o disco cresce para 1,15.
  - **Inclinação 3D:** com o dedo sobre o card, `Transform` com `Matrix4.identity()..setEntry(3,2,0.0011)..rotateX(-dy*10°)..rotateY(dx*12°)`, onde `dx` e `dy` ∈ [−0,5; 0,5] vêm da posição do toque. Volta a 0 em 180 ms ao soltar.
  - Selo absoluto em (14, 14) e nome com altura mínima de 70.
  - Rodapé com preço + botão redondo `accent` de 64.
- **Foto comum (não recortada):** `ClipOval` de 200 com borda branca de 6 e sombra, sobre o disco.
- **Pílula de categoria:** altura 88 e raio 44, com imagem circular de 68 à esquerda. A selecionada ganha fundo `text` e texto branco.

## 6. Telas

### 6.1 Descanso (`01-descanso.png`)
- **Fundo:** `bg` com um círculo decorativo `0xFFE2E8F3` de 760 cortado no canto superior direito (−260, −200).
- **Texto** (top 220, lateral 64): H1 "Monte. / Toque. / **Saboreie.**" (a última linha em `accent`) e o subtítulo 34 `muted`, com no máximo 640 de largura. `titulo` e `subtitulo` da 1ª mídia substituem o H1, se houver.
- **Palco** (top 820, altura 720): carrossel automático de 4 itens, a cada 3 s:
  - **Fonte dos itens:** produtos com `selo` e imagem, ou as `descansoMidias`.
  - **Disco:** 580, centralizado. A cor vem de `estudioDiscos[i]` (ou `categoria.cor`) e entra com escala 0,5 → 1 em 1 s (`Cubic(.2,.9,.2,1)`).
  - **Produto:** recorte de 720×540. Entra vindo da direita (+160, rotação 12°, escala 0,7) em 900 ms, com atraso de 120 ms, e depois **flutua** ±18 px em 3,4 s.
  - **Sombra elíptica** (420×40, `0x240E1A2B`) que "respira" (escala 0,8 e opacidade 0,6 no topo da flutuação).
  - **Legenda:** nome em Sora 800 46 e preço `accent` 32, com fade + subida (atraso de 300 ms).
  - **Pontos:** o ativo tem 44×14 na cor `text`, com transição de 400 ms.
- **Rodapé:** "Toque para começar" e os botões xl **Comer aqui** (primário) e **Para levar** (`soft`).

### 6.2 Catálogo (`02-cardapio.png`)
- **Topo** padrão com `Etapas(0)`.
- **Faixa de destaques** rolável na horizontal com snap (padding 12/48/28):
  - Cartões de 880×420 com raio 44 e fundo na cor do disco, com um círculo `0x2EFFFFFF` de 560 no canto inferior direito.
  - Texto à esquerda (430 de largura): selo, nome em Sora 800 62, preço 40 e pílula branca "Adicionar →".
  - Recorte de 440×360 à direita, flutuando.
  - Texto branco no cartão azul e `text` nos cartões amarelo, coral e verde.
  - Rolagem automática a cada 3,5 s (`animateTo` suave), pausada enquanto houver toque.
- **Pílulas de categoria** **fixas no topo ao rolar** (`SliverPersistentHeader`, fundo `bg`).
- **Seções:** título + grade de **3 colunas** (espaço 22) de `.ecard`.
- **`BarraSacola`:** fundo `text`, botão interno `accent`.

### 6.3 Produto (`03-produto.png`)
- **Cartão central** (margens de 48, top 90, bottom 90, raio 48, fundo `0xFFF7F9FB`, sombra `0x4D000000` com blur 80 e y 40).
- **Entrada girando:** `perspective` + `rotateY(-24°)` + escala 0,9 → 0 em 600 ms (`Cubic(.2,.9,.2,1)`).
- **Topo** (500): fundo `0xFFE4EAF6`, disco `accent` de 440 e recorte com `heroIn` + flutuação. O X fica num círculo `0x80000000`.
- **Corpo:** nome em Sora 800 78 e preço 46 `text`.
  - Grupos com cards brancos e borda 3 `line`.
  - Seleção com borda `accent` + fundo `hi` + ✓ em círculo `accent`.
- **Rodapé:** `Quantidade` (os + em `accent`) e **Adicionar · R$**.

### 6.4 Carrinho (`04-sacola.png`)
Estrutura da base, com estas diferenças:
- Lista em cartão branco com raio 38 e sombra suave.
- "Combina com seu pedido" em `surface2` com raio 38.
- Os cards de sugestão têm disco + recorte ou foto em círculo.
- Total em Sora 800 78.

### 6.5 Peça também (`05-sugestao-sobremesa.png`)
- Cartão central branco com raio 48 e sombra grande.
- Grade de 3 cards com borda `line`.
- Selecionado com borda `accent` e fundo `hi`.

### 6.6 Identificação (`06`, `07`)
- Campo branco com raio 38 e borda `line`.
- Teclas brancas com raio 26 e sombra inferior `0 5 0 line`.
- Tecla de função em `surface2`.

### 6.7 Pagamento (`08`, `09`, `10`)
- **Opções:** brancas com raio 38 e borda `line`. Ao tocar, deslizam 8 px para a direita com a borda em `accent`.
- **Pix em destaque:** fundo `hi`.
- **Nomes:** Sora 800 46.
- **Maquininha:** cartão `accent`.

### 6.8 Confirmação (`11-confirmado.png`)
- Check `accent` com anel.
- Cartão branco com a senha em Sora 800 170 `accent`.
- Confete `[accent, accent2, text, branco]`.

## 7. Animações

| Animação | Onde | Duração / curva | Implementação | Reduzido / `low` / off |
|---|---|---|---|---|
| Carrossel do palco | descanso | 3 s por item; disco 1 s; produto 900 ms | `AnimatedSwitcher` com `transitionBuilder` próprio (escala+rotação+translação) | reduzido: só fade; off: item fixo |
| Flutuação + sombra | descanso, destaques, produto | 3,4 s `easeInOut`, repeat | `AnimatedBuilder` compartilhado | parado |
| Rolagem automática dos destaques | catálogo | 3,5 s | `ScrollController.animateTo` num `Timer` (cancelar no dispose) | sem rolagem automática |
| Inclinação 3D | cards | 180 ms `easeOut` | `Listener(onPointerMove)` + `Transform` | inclinação desligada, só o press |
| Produto girando | produto | 600 ms | `PageRouteBuilder` com `Transform` perspectiva | fade simples |
| Troca de tela | todas | 550 ms, entrada da direita (+90 px) + fade | transição de página | instantâneo |
| Voo + bump, senha, recibo, confete | base | — | base | base |

## 8. Trecho de referência: inclinação 3D

```dart
class InclinaAoToque extends StatefulWidget { /* child, habilitado */ }
class _InclinaState extends State<InclinaAoToque> {
  Offset _d = Offset.zero; // -0.5..0.5
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _mover, onPointerMove: _mover,
        onPointerUp: (_) => setState(() => _d = Offset.zero),
        onPointerCancel: (_) => setState(() => _d = Offset.zero),
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _d),
          duration: const Duration(milliseconds: 180),
          builder: (_, d, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateX(-d.dy * 10 * math.pi / 180)
              ..rotateY(d.dx * 12 * math.pi / 180),
            child: child,
          ),
          child: widget.child,
        ),
      );
  void _mover(PointerEvent e) {
    if (!widget.habilitado) return;
    final box = context.findRenderObject() as RenderBox;
    final p = box.globalToLocal(e.position);
    setState(() => _d = Offset(p.dx / box.size.width - .5, p.dy / box.size.height - .5));
  }
}
```

## 9. Paleta recomendada no admin (`PALETA_PRESET.estudio`)

```ts
estudio: { corPrimaria: '#2F55F4', corDestaque: '#FFC83D', corFundo: '#EEF1F5', corPainel: '#FFFFFF', raio: 28 },
```

> Atenção: `temaDe(ap)` hoje monta `ColorScheme.dark`. As telas padrão (sem variante) não podem ficar ilegíveis com fundo claro. Com `estudio`, **ou** `temaDe` passa a gerar `ColorScheme.light` quando `corFundo` for clara (luminância > 0,5), **ou** as telas sem variante continuam com a paleta escura padrão. Escolha a primeira opção, com um teste cobrindo o caso.

## 10. Checklist de aceite

- [ ] Descanso com palco giratório (disco, recorte, sombra e legenda) e a versão estática em `off`.
- [ ] Destaques com rolagem automática, pílulas fixas ao rolar e grade de 3 colunas.
- [ ] Inclinação 3D só no perfil `high` com `animacoes: cheio`.
- [ ] Foto não recortada aparece no círculo com borda branca, sem fundo quadrado "sujo".
- [ ] Tema claro legível em todas as telas, inclusive venda não concluída e estados de erro e bloqueio.
- [ ] Demais telas conforme os PNG e os estados do 00 (seção 4).
- [ ] Testes do 00 (seção 5) verdes, sem overflow em 1080×1920 e 800×600.
- [ ] Fontes Sora e Figtree empacotadas com OFL.
