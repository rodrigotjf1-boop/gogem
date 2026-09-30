# 04 · Template **Neon 2.0** (`temaPreset: 'neon'`)

> Pré-requisito: Fase 0 do `00-base-templates.md`. Medidas em px de desenho sobre 1080 de largura (`context.dz`).

## 1. Conceito

Noite urbana com energia de fliperama:
- **Descanso:** faixas de texto gigante correm pela tela em sentidos opostos, um **anel de luz** gira em volta do burger e o letreiro "PEDE AÍ." cintila como néon.
- **Cardápio:** mosaico de fotos (bento) com bordas luminosas animadas no destaque, e tipografia larga em CAIXA ALTA.
- **Referências:** Taco Bell, smash burgers de rua, arcades.
- **Ideal para:** público jovem, madrugada e smash burger.

## 2. Mockups de referência

`mockups/04-neon-2/`. No protótipo, selecione **4. Neon 2.0**. No CSS, os seletores são `.t-neon`, `.att-neon`, `.menu-neon`, `.ntile`, `.bento`, `.glow`, `.nhero`.

## 3. Tokens

```dart
const neonTokens = TemplateTokens(
  bg: Color(0xFF07070C),
  surface: Color(0xFF12121C),
  surface2: Color(0xFF1C1C2A),
  text: Color(0xFFF4F4FA),
  muted: Color(0xFFA4A4BC),
  accent: Color(0xFFC8FF2E),     // verde-limão
  onAccent: Color(0xFF07070C),
  accent2: Color(0xFFFF3EA5),    // magenta
  onAccent2: Color(0xFF07070C),
  line: Color(0xFF262638),
  line2: Color(0xFF43435C),
  price: Color(0xFFC8FF2E),
  hi: Color(0x14C8FF2E),
  art: Color(0xFF161622),
  ok: Color(0xFFC8FF2E),
  err: Color(0xFFFF5577),
  raio: 24, raioBotao: 16, raioTecla: 14,
  fonteDisplay: 'Unbounded',
  fonteTexto: 'Rubik',
  pesoDisplay: FontWeight.w800,
  displayCaixaAlta: true,
);
const neonCiano = Color(0xFF3EE0FF); // 3ª cor, só em gradientes de brilho
/// Brilho: BoxShadow(color: Color(0x73C8FF2E), blurRadius: 26) — SÓ no perfil high.
```

## 4. Tipografia

| Uso | Fonte | Tamanho |
|---|---|---|
| "PEDE AÍ." | Unbounded 800 | 170, altura 0,9, `accent`, sombra de texto `0x8CC8FF2E` blur 30 |
| Faixas do descanso | Unbounded 800 | 150; vazadas (stroke 2 px) ou cheias |
| Títulos de tela | Unbounded 800 | 66, CAIXA ALTA, espaçamento −0,02 em |
| Título de seção | Unbounded 800 | 46 + prefixo "//" em `accent2` |
| Nome no tile | Unbounded 700 | 26 (tile grande: 40), CAIXA ALTA |
| Corpo | Rubik 400–600 | 22–30 |
| Abas | Rubik 600 | 23, CAIXA ALTA, espaçamento 0,05 em |
| Botões | Rubik 800 | 30–40, CAIXA ALTA, espaçamento 0,04 em |

Logo padrão: "NEON" em Unbounded 800 48, "/" em `accent` e, embaixo, "SMASH CLUB" em Rubik 700 16 com espaçamento 0,38 em na cor `accent2`.

## 5. Componentes

- **Botões:** raio 16. Primário com fundo `accent` e texto `onAccent`. Fantasma com borda `line2`.
- **Abas de categoria:** barra `surface` com borda `line` e raio 22, com 5 abas iguais (altura 78). A ativa tem fundo `accent`, texto `onAccent` e sombra de brilho (só `high`).
- **Tile (bento):**
  - Fundo `surface`, borda 2 `line` e raio 22. No press, a borda vira `accent` e o tile sobe 4 px.
  - Área de imagem com fundo `0xFF171724` (recorte com brilho radial `0x29C8FF2E`).
  - O selo é um retângulo de raio 10 com fundo `accent2`.
  - Botão + **quadrado** (raio 16) `accent`.
- **Grade bento:** 2 colunas e linhas de 340. O 1º item de cada categoria é **grande** (2 linhas, com descrição). Se a quantidade for par, o último item é **largo** (2 colunas, com a imagem à esquerda). Use `CustomMultiChildLayout`, um `Column` de `Row`s ou o pacote já presente no projeto. **Não adicione dependência** de staggered grid sem aprovação.
- **Borda de néon girando** (`.glow`): um `SweepGradient` `[accent, accent2, neonCiano, accent]` girando em 5 s por trás do tile e recortado para aparecer só como uma borda de 3 px (tile interno com inset de 3).

## 6. Telas

### 6.1 Descanso (`01-descanso.png`)
- **Faixas:** 6 linhas giradas em −8°, deslocadas (−160 à esquerda e à direita), começando em top 190.
  - Textos: "SMASH ✦ BACON ✦ CHEDDAR ✦", "FOME DE MADRUGADA ✦", "ABERTO ATÉ 4H ✦" e "PEDE AÍ ✦". O lojista pode trocar via `chamada` e o `kicker` das mídias.
  - Alternância: vazada verde `0x38C8FF2E`, vazada magenta `0x47FF3EA5` e **cheia** `0xE6C8FF2E` (só a 3ª linha).
  - Movimento: a linha ímpar corre para a esquerda em 26 s e a par para a direita em 30 s, em loop contínuo.
- **Scanlines:** listras horizontais de 2 px `0x09FFFFFF` a cada 6 px, estáticas, desenhadas uma vez num `CustomPainter`.
- **Palco** (top 500, altura 820):
  - **Anel 1** (740, em 170/40): borda de 10 px com `SweepGradient` `[accent, accent2, transparente 55%, accent]` girando em 4 s, com brilho (só `high`).
  - **Anel 2** (840): `SweepGradient` `[accent2, transparente 30%, neonCiano 60%, transparente 80%]` girando em 7 s no sentido **inverso**, com opacidade de 60%.
  - **Burger:** recorte de 640×520 flutuando ±18 px em 3 s, com brilho `0x59C8FF2E` blur 50.
  - **Adesivo** (top 60, right 70, rotação 9°): fundo `accent2`, "COMBO DA NOITE" + `precoIsca` em Unbounded 800 54. Balança (rotação 9° ↔ 3° + escala 1,04) em 2,6 s.
  - Sem `precoIsca`, o adesivo mostra o selo e o preço do 1º produto com `selo`.
- **Rodapé:**
  - "PEDE AÍ." com **cintilação**: keyframes em 4 s com opacidade 1 → 0,35 nos pontos 20% e 63%.
  - Ponto magenta piscando (1 s, degrau) e "TOQUE NA TELA PARA COMEÇAR".
  - Botões **COMER AQUI** (primário) e **PARA LEVAR** (fantasma).

### 6.2 Catálogo (`02-cardapio.png`)
- **Topo** padrão com `Etapas(0)` e as abas de categoria abaixo (fixas).
- **Coluna rolável** (padding 24/48):
  1. **Destaque** (altura 370, raio 26):
     - Borda de néon girando e fundo interno `0xFF0E0E17`.
     - Texto: kicker `accent2` "COMBO DA NOITE · ATÉ 4H" (ou o `selo` do produto), nome em Unbounded 800 46 e preço `accent` 50 com o antigo riscado.
     - Dois recortes flutuando (burger 360×300 e batata 230×200) com fase defasada.
     - Fonte: 1º produto com `selo` (ou `precoIsca`).
  2. **Seções:** título "// CATEGORIA" + grade bento.
- **`BarraSacola`:** fundo `accent`, texto `onAccent`, botão interno com fundo `onAccent` e texto `accent`.

### 6.3 Produto (`03-produto.png`)
- **Folha** que sobe (top 60, raio superior 52, fundo `0xFF0C0C14`).
- **Topo** com brilho radial verde, recorte com `heroIn` + flutuação e o nome gigante vazado ao fundo ("2X / BACON", derivado do nome do produto).
- **Corpo:** nome em Unbounded 800 62 CAIXA ALTA e preço `accent` em Unbounded 50.
  - Grupos: título "TURBINE" em `accent2`.
  - Opções em grade de 2 colunas com borda `accent` quando selecionadas.
- **Rodapé:** `Quantidade` (os + em `accent` com ícone escuro) e **ADICIONAR R$**.

### 6.4 Carrinho (`04-sacola.png`)
- Título "SACOLA" + contagem com 2 dígitos em `accent2` (Unbounded 88).
- **Lista:** fundo `surface`, borda **tracejada** 2 px `line2` e raio 24.
- **"Combina com você":** borda 2 px `accent2` e brilho magenta `0x33FF3EA5` blur 30 (só `high`).
- **Total:** Unbounded 800 66 `accent`, dentro de um cartão `surface` com borda `line`.

### 6.5 Peça também (`05-sugestao-sobremesa.png`)
- Cartão `0xFF0C0C14` com raio 34.
- Título em Unbounded 800 52 CAIXA ALTA.
- Grade de 3 cards `surface`, com o + em quadrado `accent`.

### 6.6 Identificação (`06`, `07`)
- Campo `surface` com borda `line`.
- Teclas com borda 2 `line`, **sem sombra** e raio 14. Ao tocar, a borda vira `accent`.
- O texto digitado no CPF fica em `accent` quando válido.

### 6.7 Pagamento (`08`, `09`, `10`)
- **Opções:** borda 2 `line`. Pix com borda `accent` e fundo `hi`.
- **Nomes:** Unbounded 800 46 CAIXA ALTA.
- **QR:** cantos `accent` e varredura `accent` com brilho.
- **Maquininha:** cartão `accent`.

### 6.8 Confirmação (`11-confirmado.png`)
- Check `accent` com anel.
- "PEDIDO CONFIRMADO!" em Unbounded 88.
- Senha em Unbounded 800 170 `accent` com brilho de texto.
- Confete `[accent, accent2, neonCiano, branco]`.

## 7. Animações

| Animação | Onde | Duração / curva | Implementação | Reduzido / `low` / off |
|---|---|---|---|---|
| Faixas correndo | descanso | 26 s / 30 s, linear, repeat | um `AnimationController` para todas; cada faixa é `Transform.translate(x: -v * largura)` de 2 cópias do texto lado a lado (`Row` com `OverflowBox`) | **estáticas** (no mesmo lugar) |
| Anéis girando | descanso | 4 s e 7 s, linear | `RotationTransition` de um `CustomPaint` com `SweepGradient` (paint.style stroke, largura 10) | anel parado; sem brilho no `low` |
| Cintilação do letreiro | descanso | 4 s (keyframes 20%, 63%) | `TweenSequence` de opacidade | opacidade 1 |
| Ponto piscando | descanso | 1 s, degrau | `AnimationController` + `value < .5` | aceso |
| Adesivo balançando | descanso | 2,6 s `easeInOut` | `Transform.rotate` + scale | parado |
| Borda de néon girando | destaque, tile grande | 5 s, linear | `CustomPaint` com `SweepGradient` rotacionado (`GradientRotation`) em stroke | borda sólida `accent` 3 px |
| Glitch de entrada | troca de tela | 500 ms, 5 passos | `ClipRect` com `heightFactor` e deslocamento x (−16, 14, −8, 0) em degraus | fade simples |
| Voo + bump, senha, recibo, confete | base | — | base | base |

> Desempenho: faixas, anéis e borda juntos custam caro. No perfil `low`, **nenhum** desses loops pode existir. Meça no Tinker Board: o descanso Neon deve ficar **≥ 45 fps** no `high` e sem animação contínua no `low`.

## 8. Trecho de referência: anel girando

```dart
class AnelNeon extends StatelessWidget {
  const AnelNeon({super.key, required this.giro, required this.cores, this.largura = 10});
  final Animation<double> giro; // 0..1, repeat
  final List<Color> cores;
  final double largura;
  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: giro,
        child: CustomPaint(painter: _AnelPainter(cores, context.dz(largura))),
      );
}
class _AnelPainter extends CustomPainter {
  _AnelPainter(this.cores, this.w);
  final List<Color> cores; final double w;
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    c.drawOval(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..shader = SweepGradient(colors: cores).createShader(r));
  }
  @override
  bool shouldRepaint(_AnelPainter o) => false; // gira via RotationTransition, sem repintar
}
```

## 9. Paleta recomendada no admin (`PALETA_PRESET.neon`)

```ts
neon: { corPrimaria: '#C8FF2E', corDestaque: '#FF3EA5', corFundo: '#07070C', corPainel: '#12121C', raio: 16 },
```

## 10. Checklist de aceite

- [ ] Descanso com faixas, scanlines, dois anéis, adesivo e letreiro cintilando, e o quadro estático em `off` / `low`.
- [ ] Grade bento com tile grande e tile largo corretos para qualquer quantidade de produtos (1, 2, 3, 4, 7…).
- [ ] Borda de néon girando só no destaque e no tile grande.
- [ ] Brilhos (`BoxShadow` com blur) desligados no perfil `low`.
- [ ] Demais telas conforme os PNG e os estados do 00 (seção 4).
- [ ] Testes do 00 (seção 5) + teste da montagem bento com 1, 2, 3 e 5 itens.
- [ ] Medição de fps no PR (`high`) e confirmação de que não há `AnimationController` rodando no `low`.
- [ ] Fontes Unbounded e Rubik empacotadas com OFL.
