# 05 · Template **Diner 58** (`temaPreset: 'diner'`)

> Pré-requisito: Fase 0 do `00-base-templates.md`. Medidas em px de desenho sobre 1080 de largura (`context.dz`).

## 1. Conceito

Lanchonete americana dos anos 50:
- **Descanso:** fundo vermelho, **letreiro com lâmpadas que acendem em sequência**, "Aberto" em néon verde, fotos redondas com moldura creme balançando e uma **faixa quadriculada correndo** no rodapé.
- **Cardápio:** parece uma lousa de diner, com botões de "jukebox", fotos redondas, linhas pontilhadas até o preço e preços em selos vermelhos inclinados.
- **Referências:** Johnny Rockets, Steak 'n Shake, diners americanos.
- **Ideal para:** hamburguerias temáticas, milkshake e público família.

## 2. Mockups de referência

`mockups/05-diner-58/`. No protótipo, selecione **5. Diner 58**. No CSS, os seletores são `.t-diner`, `.att-diner`, `.menu-diner`, `.dn-*`, `.jbox`, `.drow`, `.bulbs`, `.checker`.

## 3. Tokens

```dart
const dinerTokens = TemplateTokens(
  bg: Color(0xFFFFF4E2),          // creme
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFFBE6C8),
  text: Color(0xFF2A1512),        // marrom-café (contornos e sombras "duras")
  muted: Color(0xFF6E4E45),
  accent: Color(0xFFD3202A),      // vermelho diner
  onAccent: Color(0xFFFFF4E2),
  accent2: Color(0xFF8FD5C7),     // menta
  onAccent2: Color(0xFF2A1512),
  line: Color(0xFFEED6B6),
  line2: Color(0xFFC9A987),
  price: Color(0xFFD3202A),
  hi: Color(0xFFFFE7E3),
  art: Color(0xFFFDEBD0),
  ok: Color(0xFF1E8F6E),
  err: Color(0xFFD3202A),
  raio: 30, raioBotao: 999, raioTecla: 22,
  fonteDisplay: 'Bungee',
  fonteTexto: 'Nunito',
  pesoDisplay: FontWeight.w400,
  claro: true,
);
const dinerCursiva = 'Yellowtail';
const dinerLampada = Color(0xFFFFE7A0);      // brilho: BoxShadow(0xFFFFD35A, blur 14)
const dinerVermelhoEscuro = Color(0xFF8F141B); // sombra 3D do letreiro
/// Sombra "dura" de contorno: BoxShadow(color: text, offset: Offset(0, 6), blurRadius: 0)
```

É um template **claro**: siga a mesma observação do `03-estudio.md` sobre `ColorScheme.light`.

## 4. Tipografia

| Uso | Fonte | Tamanho |
|---|---|---|
| "Diner" no letreiro | Yellowtail | 230, `accent`, sombra de texto 6/6 `text` sem blur |
| "58" | Bungee | 84, fundo `text`, texto `bg`, raio 18, rotação 8° |
| "Aberto" / "Especial do dia" / "Toque para começar" | Yellowtail | 58–74 |
| Títulos de tela | Bungee | 62 |
| Título de seção | Bungee | 48 `accent`, centralizado, com ★ nas pontas |
| Nome na linha do cardápio | Bungee | 32 |
| Preço em selo | Bungee | 28 |
| Corpo | Nunito 600–900 | 23–40 |
| Botões | Nunito 800 | 30–40 |

Logo padrão: "Diner" em Yellowtail 66 `accent` + "58" em Bungee 34 num bloco `text` girado −6°, com "BURGERS · SHAKES" em Bungee 15 embaixo. Na loja, use `nomeLoja` em Yellowtail + `logoUrl` se houver.

## 5. Componentes

- **Botões:** pílula. Primário `accent`. `mint` com fundo `accent2` e texto `text`. No descanso, o primário fica **invertido** (fundo `bg`, texto `accent`), porque o fundo é vermelho.
- **Lâmpadas:** círculos de 22 (16 no cabeçalho) `dinerLampada` com brilho. **Perseguição:** cada lâmpada tem atraso de `i × 80 ms` num ciclo de 1,6 s (acesa de 0 a 40%, apagada com opacidade 0,25 e sem brilho de 50 a 90%).
- **Botão jukebox (categoria):** altura 100, raio 24, borda 4 `text`, fundo branco e sombra dura 0/6.
  - Uma "luz" de 14 no canto (cinza; `0xFFFF4040` com brilho quando ativa).
  - O ativo ganha fundo `accent2`, desce 4 px e a sombra reduz para 0/2.
- **Linha do cardápio:**
  - **Foto redonda** de 176 com borda branca de 8, anel `accent` de 4 e sombra `0x1F2A1512` 0/12. No press, gira −8° e escala 1,05 (400 ms `elasticOut`).
  - Nome em Bungee + **pontilhado** até o fim.
  - Descrição 23 `muted`.
  - Coluna direita com o **selo de preço** (fundo `accent`, texto `bg`, raio 14, rotação −3°) e o botão + de 76 com fundo `text`.
- **Separador de linhas:** pontilhado de 4 px `line`.
- **Caixas tracejadas:** borda 4 px tracejada `accent` (especial do dia, sugestões, cartão da senha).

## 6. Telas

### 6.1 Descanso (`01-descanso.png`)
- **Fundo** `accent` inteiro.
- **Letreiro** (left 80, right 80, top 170, altura 560, raio 44):
  - Fundo `bg`, borda 10 `text` e sombra 0/18 `dinerVermelhoEscuro` sem blur.
  - **Lâmpadas nas 4 bordas:** 22 em cima, 22 embaixo e 9 em cada lateral.
  - "Aberto" em Yellowtail 62, `ok` com brilho menta, girado −10° no canto superior esquerdo e cintilando.
  - Centro com "Diner" + selo "58" + "BURGERS · SHAKES · FRITAS" em Bungee 30.
  - Com `logoUrl`, a logo fica no centro no lugar do texto e as lâmpadas continuam.
- **Fotos redondas** (top 800): 3 círculos de 320, 430 e 310 com borda `bg` de 14 e sombra dura `0x2E000000` 0/20.
  - **Balançam** ±18 px em 3,2 s com fases −0,8 s, 0 e −1,6 s.
  - Cada foto tem um selo de preço (fundo `text`, texto `bg`, Bungee 30, rotação −5°) centralizado embaixo.
  - Fonte: `descansoMidias` (até 3) ou os produtos com `selo`/foto.
- **Frase** (top 1350) em Nunito 900 40 `bg`, centralizada: "Milkshake batido na hora…". Vem do `subtitulo` da 1ª mídia, e sem ele de `chamada`.
- **Rodapé** (padding inferior 150):
  - "Toque para começar" em Yellowtail 74 `accent2` com brilho e cintilação.
  - **Comer aqui** (invertido) e **Para levar** (`mint`).
- **Faixa quadriculada** (altura 96) no pé da tela, com casas de 48 `text`/`bg`, deslizando 96 px a cada 3 s em loop.

### 6.2 Catálogo (`02-cardapio.png`)
- **Cabeçalho vermelho:**
  - Fileira de 18 lâmpadas no topo (perseguição).
  - Topo padrão com cores invertidas: logo, textos e botões em `bg` e o **Cancelar** com borda `0x73FFF4E2`.
  - `Etapas(0)` em `bg`.
- **Jukebox:** fileira de 5 botões (padding 22/40), sobre fundo listrado vertical `surface2`/`bg` de 30 px e borda inferior de 6 `text`.
- **Coluna rolável** (padding 24/40):
  1. **Especial do dia** (altura mínima 330, raio 30, fundo branco, borda tracejada `accent`):
     - À esquerda (560): "Especial do dia" em Yellowtail 58 `accent`, nome em Bungee 40, descrição 24 e preço em Bungee 48.
     - À direita: a foto em cover.
     - Fonte: 1º produto com `selo`.
  2. **Seções:** título "★ Categoria ★" + linhas do cardápio.
- **`BarraSacola`:** fundo `text`, texto `bg` e sombra dura 0/8 `accent`. Botão interno `accent`.

### 6.3 Produto (`03-produto.png`)
- **Cartão central** (margens de 48, top e bottom 90, raio 48) com borda 6 `text` e sombra dura 0/14 `text`, entrando com pop (escala 0,86 → 1, 450 ms, `Cubic(.2,1.2,.4,1)`).
- **Topo** (500) com fundo **xadrez** creme (`0xFFFBE6C8`/`bg`, casas de 40) e o recorte com `heroIn` + flutuação. Foto comum entra num círculo com borda branca.
- **Corpo:**
  - Nome em Bungee 56 e preço 46 `accent`.
  - Grupos com cards brancos, borda 3 `line` e seleção com borda `accent` + fundo `hi`.
  - Chips de remoção em pílula.
- **Rodapé:** `Quantidade` (os + em `accent`) e **Adicionar · R$** em pílula `accent`.

### 6.4 Carrinho (`04-sacola.png`)
- Fundo `bg`, título em Bungee 62 e lista em cartão branco com sombra suave.
- **"Combina com seu pedido":** fundo branco com borda tracejada 4 `accent` e título em Bungee 36.
- **Total:** Bungee 60 `accent`.

### 6.5 Peça também (`05-sugestao-sobremesa.png`)
- Cartão central `0xFFFFF8EE` com borda 6 `text` e sombra dura.
- Título em Bungee 50.
- Cards com borda `line`, e o + em círculo `accent`.

### 6.6 Identificação (`06`, `07`)
- Campo branco com borda 3 `line`.
- **Teclas:** fundo branco, **borda 3 `text` e sombra dura 0/5 `text`**, como botões de máquina antiga. Ao tocar, descem 4 px e a sombra reduz para 0/1.
- Tecla de função em `surface2`.

### 6.7 Pagamento (`08`, `09`, `10`)
- **Opções:** brancas com borda `line`. Pix com fundo `hi` e borda `accent`.
- **Nomes:** Bungee 40.
- **Resumo:** fundo `surface2`.
- **QR:** cantos `accent`.
- **Maquininha:** cartão `accent`.

### 6.8 Confirmação (`11-confirmado.png`)
- Check `accent` com anel.
- "Pedido confirmado!" em Bungee 88.
- **Cartão da senha** com borda tracejada 4 `accent` e a senha em Bungee 170 `accent`.
- Confete `[accent, accent2, text, branco]`.

## 7. Animações

| Animação | Onde | Duração / curva | Implementação | Reduzido / `low` / off |
|---|---|---|---|---|
| Lâmpadas em perseguição | letreiro, cabeçalho | ciclo de 1,6 s, atraso de 80 ms por lâmpada | **um** `AnimationController` (1,6 s repeat). Cada lâmpada calcula `fase = (t - i*0.05) % 1` e a opacidade vem da tabela de keyframes. Tudo num `CustomPainter` (nada de 60 widgets animados) | todas acesas, sem brilho no `low` |
| "Aberto" / "Toque para começar" cintilando | descanso | 4,5–5 s keyframes | `TweenSequence` de opacidade | opacidade 1 |
| Fotos balançando | descanso | 3,2 s `easeInOut`, fases defasadas | 1 controller + `sin(2π·(t+fase))` | paradas |
| Faixa quadriculada | descanso | 3 s linear | `CustomPainter` com deslocamento x = `t × 96` | parada |
| Jukebox pressionado | catálogo | 150 ms | `AnimatedContainer` (translate y + sombra) | igual |
| Foto redonda girando ao tocar | catálogo | 400 ms `elasticOut` | `AnimatedRotation` + `AnimatedScale` | sem rotação |
| Selo de preço girando ao adicionar | catálogo | 500 ms | `RotationTransition` −3° → 357° | sem rotação |
| Pop do cartão | produto, peça também | 450–600 ms `Cubic(.3,1.4,.5,1)` | transição de rota | fade |
| Troca de tela | todas | 600 ms, subida de 60 px + escala 0,97 → 1 com "quique" | transição de página | instantâneo |
| Voo + bump, senha, recibo, confete | base | — | base | base |

## 8. Trecho de referência: lâmpadas num `CustomPainter`

```dart
class LampadasPainter extends CustomPainter {
  LampadasPainter({required this.t, required this.pontos, required this.raio, required this.brilho})
      : super(repaint: t);
  final Animation<double> t;        // 0..1, 1,6 s repeat
  final List<Offset> pontos;        // posições pré-calculadas (bordas do letreiro)
  final double raio;
  final bool brilho;                // false no perfil low
  final _p = Paint();
  final _g = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

  double _opacidade(double f) => f < .40 ? 1 : f < .50 ? 1 - (f - .40) * 7.5 : f < .90 ? .25 : .25 + (f - .90) * 7.5;

  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < pontos.length; i++) {
      final f = (t.value - i * 0.05) % 1.0;
      final a = _opacidade(f < 0 ? f + 1 : f);
      if (brilho && a > .9) { _g.color = const Color(0xB3FFD35A); c.drawCircle(pontos[i], raio * 1.6, _g); }
      _p.color = const Color(0xFFFFE7A0).withAlpha((255 * a).round());
      c.drawCircle(pontos[i], raio, _p);
    }
  }
  @override
  bool shouldRepaint(LampadasPainter o) => false;
}
```

## 9. Paleta recomendada no admin (`PALETA_PRESET.diner`)

```ts
diner: { corPrimaria: '#D3202A', corDestaque: '#8FD5C7', corFundo: '#FFF4E2', corPainel: '#FFFFFF', raio: 24 },
```

## 10. Checklist de aceite

- [ ] Letreiro com lâmpadas em perseguição, feito com **um** controller e **um** painter.
- [ ] "Aberto" e a chamada cintilando, fotos redondas balançando e faixa quadriculada correndo. Em `off`/`low`, tudo parado e legível.
- [ ] Botões jukebox com estado ativo e rolagem sincronizada com as seções.
- [ ] Linhas do cardápio com foto redonda, pontilhado até o preço e selo inclinado.
- [ ] Tema claro legível em todas as telas (ver a observação do 03).
- [ ] Teclado com sombra dura e efeito de tecla afundando.
- [ ] Demais telas conforme os PNG e os estados do 00 (seção 4).
- [ ] Testes do 00 (seção 5) verdes, sem overflow.
- [ ] Fontes Bungee, Yellowtail e Nunito empacotadas com OFL.
