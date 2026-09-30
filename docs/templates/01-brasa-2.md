# 01 · Template **Brasa 2.0** (`temaPreset: 'brasa2'`)

> Pré-requisito: Fase 0 do `00-base-templates.md` já em `main`. Todas as medidas são em px de desenho sobre 1080 de largura: use `context.dz(n)`.

## 1. Conceito

Steakhouse premium com fogo de verdade:
- **Descanso:** a foto de um burger entre chamas ocupa a tela, com zoom lento e brasas subindo em tempo real.
- **Resto do fluxo:** escuro e aconchegante, com fotos iluminadas por um brilho laranja por trás, títulos em serifa elegante e preços em âmbar.
- **Referências:** Madero, Outback, hamburguerias artesanais.
- **Ideal para:** ticket médio alto e operação noturna.

## 2. Mockups de referência

`mockups/01-brasa-2/`, com cada PNG em 1080×1920:

| Arquivo | Tela |
|---|---|
| `00-prancha.png` | visão geral |
| `01-descanso.png` | descanso |
| `02-cardapio.png` | catálogo |
| `03-produto.png` | produto (mostra o combo da Fase B; em Fase A são os grupos de complemento) |
| `04-sacola.png` | carrinho com "Combina com seu pedido" |
| `05-sugestao-sobremesa.png` | peça também |
| `06-cpf.png` / `07-nome.png` | identificação, etapas 1 e 2 |
| `08-pagamento.png` | escolha da forma (em Fase A é **Cartão** único) |
| `09-pix.png` | PIX |
| `10-cartao-maquininha.png` | Point |
| `11-confirmado.png` | confirmação |

Movimento: abra `mockups/prototipo-interativo.html` e selecione **1. Brasa 2.0**. As medidas exatas estão em `referencia/prototipo-kiosk.css` (seletores `.t-brasa`, `.att-brasa`, `.menu-brasa`).

## 3. Tokens

`lib/features/templates/brasa2/brasa2_tokens.dart`:

```dart
const brasa2Tokens = TemplateTokens(
  bg: Color(0xFF120E0C),
  surface: Color(0xFF1E1815),
  surface2: Color(0xFF2A221D),
  text: Color(0xFFF7EFE6),
  muted: Color(0xFFB9A897),
  accent: Color(0xFFEC7433),     // laranja brasa
  onAccent: Color(0xFF1A0C04),
  accent2: Color(0xFFF4B63F),    // âmbar (preços, selos)
  onAccent2: Color(0xFF1A0C04),
  line: Color(0xFF34291F),
  line2: Color(0xFF5B4A3E),
  price: Color(0xFFF4B63F),
  hi: Color(0x21EC7433),         // item selecionado
  art: Color(0xFF241C18),
  ok: Color(0xFF6FCF97),
  err: Color(0xFFFF7A6B),
  raio: 30, raioBotao: 22, raioTecla: 24,
  fonteDisplay: 'DMSerifDisplay',
  fonteTexto: 'Manrope',
  pesoDisplay: FontWeight.w400,
);
/// Brilho atrás das fotos: RadialGradient(center 50%/62%, raio .62,
/// [Color(0x6BEC7433), Color(0x00EC7433)]) sobre Color(0xFF221A16).
const brasa2FundoModal = Color(0xFF16110E);
```

## 4. Tipografia

| Uso | Fonte | Tamanho | Observação |
|---|---|---|---|
| Título do descanso | DM Serif Display | 150, altura 0,94 | a 2ª linha em *itálico* na cor `accent` |
| Título de tela (h1) | DM Serif Display | 92 | "Sua sacola", "CPF na nota?" |
| Título de seção do catálogo | DM Serif Display | 66 | |
| Nome no card | DM Serif Display | 38 | até 2 linhas |
| Nome no produto | DM Serif Display | 78 | |
| Total | DM Serif Display | 78 | |
| Kicker / eyebrow | Manrope 800 | 26, espaçamento 0,2 em, CAIXA ALTA | cor `accent` |
| Corpo | Manrope 600 | 28–32 | cor `muted` |
| Preço | Manrope 800 | 34 (card), 46 (produto) | cor `price` |
| Botão | Manrope 800 | 34 (lg), 40 (xl) | |

Logo padrão (sem `logoUrl`): ícone de chama `accent`, "BRASA" em DM Serif 48 com espaçamento 0,26 em e, embaixo, "BURGER & STEAK" em Manrope 700 16 com espaçamento 0,42 em na cor `muted`. Com `logoUrl`, mostre a imagem com altura 64.

## 5. Componentes

- **Botão primário:** altura 124 (xl: 170), raio 22, fundo `accent`, texto `onAccent`. Ao tocar, escala 0,97 por 150 ms.
- **Botão fantasma:** borda 3 px `line2`, texto `text`, fundo transparente.
- **Card de produto:** fundo `surface`, raio 30 e padding 16/16/22.
  - Área da foto com 250 de altura, raio 22 e fundo de brilho quente (tokens).
  - Foto `recorte` com no máximo 86% da área, ou `foto` em cover.
  - Selo no canto superior esquerdo (12, 12).
  - Nome, descrição em 2 linhas `muted` 22 e rodapé com preço + botão redondo 76 `accent` com ícone +.
  - No press, a foto escala até 1,06 (400 ms).
- **Selo:** pílula de altura 44 e raio 22. "Mais pedido" usa fundo `accent2` com estrela. Outros usam fundo `text` e texto `bg`.
- **Pílula de idioma e acessível:** altura 64, borda `line2` (Fase B).

## 6. Telas

### 6.1 Descanso (`01-descanso.png`)
- **Fundo:**
  - `descansoMidias[i].url` em cover, alinhado a 40%/50%. Sem mídias, use a arte padrão: a foto mais vendida do catálogo (1º produto com `selo`) em cover.
  - Ken Burns: escala 1,06 → 1,2 e translação −2%, em 20 s ida e volta (`repeat(reverse: true)`).
  - Várias mídias: crossfade de 1,2 s a cada `intervaloSeg`.
- **Sombreamento:** `LinearGradient` vertical com as paradas `[0: 0xD90C0907, 0.22: transparente, 0.42: transparente, 0.66: 0xE00C0907, 0.84: 0xFF0C0907]`.
- **Brasas:** `CustomPainter` com 90 partículas.
  - Nascem em x ∈ [200, 880] e y ∈ [1500, 1900] e sobem 0,6–2,4 px por quadro, com oscilação senoidal em x (amplitude 0,5).
  - Raio 1,5–5 e vida 380–880 quadros.
  - Cada uma é um gradiente radial `rgba(255,214,140,a) → rgba(255,120,40,.7a) → transparente` com `BlendMode.plus`.
  - Morrem acima de y = 200. Só com `particulas`.
- **Topo:** 56 px das bordas, logo à esquerda (as pílulas PT/EN/ES e acessível são Fase B).
- **Texto** (base a 470 do rodapé):
  - Eyebrow "Grelhado na brasa · feito na hora", ou `kicker` da mídia.
  - H1 "Fogo alto. / *Sabor que marca.*", ou `titulo`/`subtitulo` da mídia.
  - Letreiro rotativo de ofertas: 3 frases que trocam a cada 3,2 s com fade + subida de 24 px em 600 ms. A fonte são os produtos com `selo` ("**Nome** R$ preço"). Com `precoIsca`, ele entra como 1ª frase.
- **Rodapé** (padding 56/72):
  - "Toque para começar" (`ap.chamada`) com ícone de mão e um anel `accent` pulsando (escala 0,7 → 1,8, opacidade 0,9 → 0, 1,8 s).
  - Dois botões xl lado a lado: **Comer aqui** (primário) e **Para levar** (fantasma).

### 6.2 Catálogo (`02-cardapio.png`)
- **Topo:** logo (0,78) à esquerda. À direita, [acessível Fase B] e **Cancelar** (borda `line`, texto `muted`). Embaixo, `Etapas(0)`.
- **Corpo** em linha:
  - **Trilho de categorias** de 190 de largura. Cada botão tem um círculo de 104 com a imagem da categoria (ou a `cor` com a inicial) e o nome em Manrope 800 23. O selecionado ganha fundo `accent`, texto `onAccent` e raio 26, com transição de 300 ms.
  - **Coluna rolável** (padding 8/40/0/18):
    1. **Carrossel de destaques** (altura 340, raio 30): até 3 produtos com `selo`.
       - Foto em cover com Ken Burns de 8 s.
       - Degradê horizontal `0xEB120E0C → 0x99120E0C (45%) → transparente (75%)`.
       - Texto a 40 px da borda: kicker `accent` ("Combo da casa" / `selo`), nome em DM Serif 56 e preço `accent2` 38.
       - Troca a cada 3,8 s com crossfade de 1 s. Pontos no canto inferior direito, com o ativo em 40×12.
    2. **Seções por categoria:** título em DM Serif 66 e grade de 2 colunas (espaço 22) com os cards da seção 5.
  - `BarraSacola` com fundo `accent`, texto `onAccent` e botão interno "Ver sacola" com fundo `onAccent` e texto `text`.

### 6.3 Produto (`03-produto.png`)
- **Folha** que sobe de baixo (500 ms, `Cubic(.2,.9,.2,1)`): começa em top 60, com raio superior 52 e fundo `brasa2FundoModal`. Abaixo dela, véu `0x94000000`.
- **Topo da folha** (500 de altura): brilho radial quente, foto `recorte` com no máximo 420 de altura e `heroIn` (escala 0,6 → 1 e rotação −10° → 0 em 700 ms, `Curves.elasticOut` suave), seguido de flutuação ±18 px em 3,4 s. O X fica num círculo de 88 `0x80000000` no canto superior direito.
- **Corpo** rolável (padding 34/48):
  - Nome em DM Serif 78, descrição 28 `muted` e preço 46.
  - Grupos: título em Manrope 800 23 `muted` CAIXA ALTA. Cada opção é um card (raio 22, borda 3 `line`; selecionada com borda `accent` e fundo `hi`, mais o ✓ num círculo `accent` de 44 que entra com pop).
  - Grupo sem imagem: grade de 2 colunas com nome + "+ R$ 3,00" ou "incluso".
- **Rodapé** (padding 24/48/40, borda superior `line`): `Quantidade` grande (92) e botão primário **Adicionar · R$ 61,90** que ocupa o resto.

### 6.4 Carrinho (`04-sacola.png`)
- **Topo:** `Etapas(1)` e botão **Voltar**.
- H1 "Sua sacola" em DM Serif 92 e "2 itens" em 30 `muted`, alinhados pela linha de base.
- **Lista** (fundo `surface`, raio 30, padding 6/32), cada linha com:
  - miniatura de 150 (raio 22, fundo `art`)
  - nome em Manrope 800 36 e total em 34
  - complementos em 24 `muted`
  - lixeira (64, borda `line`) e `Quantidade` pequena
- **Seletor de consumo** Comer aqui / Para levar: dois botões segmentados (altura 96).
- **"Combina com seu pedido":**
  - Caixa com borda **tracejada** 3 px `line2`, raio 30 e padding 32, entrando com fade + subida em 500 ms (atraso 150 ms).
  - Título em DM Serif 48 com o ícone de brilho `accent`.
  - Grade de 3 cards de sugestão (foto 180, nome 26, preço 28, botão + de 64).
- **Rodapé:** faixa "Você economizou…" só na Fase B; linha "Total" 36 / valor em DM Serif 78; botões **Adicionar mais** (fantasma) e **Finalizar pedido** (primário, 1,6× mais largo).

### 6.5 Peça também (`05-sugestao-sobremesa.png`)
Cartão centralizado (margens de 64, raio 40, fundo `brasa2FundoModal`) sobre véu, entrando com escala 0,9 → 1 e subida em 500 ms:
- Título em DM Serif 68, por exemplo "Uma sobremesa pra fechar?". Se as sugestões forem de categorias mistas, use "Que tal completar?".
- Subtítulo 30 `muted` e grade de 3 com foto 210 (raio 16), nome, preço `price` e botão + de 62 no canto superior direito da foto.
- Botão principal de largura total.

### 6.6 Identificação (`06-cpf.png`, `07-nome.png`)
- `Etapas(2)`.
- Ícone num círculo `surface2` de 124, com o ícone `accent`.
- H1 de 92 e subtítulo 32 `muted`.
- **Campo:** altura 160, raio 30, fundo `surface`, borda 3 `line`. O CPF vai em 74 com os dígitos vazios em `muted` a 45%.
- **Teclas:** altura 134, raio 24, fundo `surface`, sombra inferior `0 5 0 line`. Ao tocar, descem 4 px.
- **Rodapé:** **Pular** (fantasma) e **Continuar** (primário).

### 6.7 Pagamento (`08`, `09`, `10`)
- **Escolha:** opções com altura aproximada de 184, raio 30, padding 30/40, ícone num quadrado de 124.
  - Pix destacada com borda `accent`, fundo `hi` e ícone com fundo `accent`.
  - Nome em DM Serif 52, selo "Mais rápido" `accent2` e seta à direita.
  - Resumo em `surface2` com raio 30.
- **PIX:**
  - QR de 600 com 40 de padding branco e raio 40, cantos `accent` de 9 px e varredura `accent` com brilho.
  - Total em DM Serif 92 e pílula "Expira em mm:ss" em `surface2`.
- **Point:** maquininha escura (380×600, raio 52) com tela verde clara. O cartão `accent` se aproxima (translação/rotação em 2,6 s), com ondas de aproximação.

### 6.8 Confirmação (`11-confirmado.png`)
- Logo no topo.
- Check `accent` de 190 (pop 600 ms `elasticOut`) com anel pulsando.
- Kicker `accent`, H1 "Pedido confirmado!" em 88 e cartão `surface` com a senha em DM Serif 170 `accent`.
- Recibo, confete nas cores `[accent, accent2, text, branco]` e botão **Fazer novo pedido** (soft `surface2`).

## 7. Animações

| Animação | Onde | Duração / curva | Implementação | Com `particulas=false` ou `anima=false` |
|---|---|---|---|---|
| Ken Burns | descanso, destaque, foto do produto | 20 s / 8 s / 12 s, `easeInOut`, `repeat(reverse)` | `AnimatedBuilder` + `Transform.scale` | quadro fixo em escala 1,1 |
| Brasas | descanso | contínua, 60 fps | `CustomPainter` + `Ticker` | **desligadas** |
| Letreiro de ofertas | descanso | 3,2 s por item, fade 600 ms | `AnimatedSwitcher` | mostra só o 1º |
| Anel de toque | descanso | 1,8 s, `easeOut`, repeat | `ScaleTransition` + `FadeTransition` | anel estático |
| Carrossel de destaques | catálogo | 3,8 s por item, crossfade 1 s | `PageView` automático ou `AnimatedSwitcher` | sem troca automática |
| Folha do produto | produto | 500 ms `Cubic(.2,.9,.2,1)` | rota com `SlideTransition` | instantâneo |
| Herói do produto | produto | 700 ms entrada + 3,4 s flutuação | `TweenSequence` | sem flutuação |
| Voo para a sacola + bump | catálogo, produto | 820 ms + 500 ms | `VooParaSacola` (base) | só o bump |
| Troca de tela | todas | 550 ms fade + subida de 40 px | `CustomTransitionPage` no go_router **ou** `AnimatedSwitcher` no nível da tela | instantâneo |
| Senha contando, recibo, confete | confirmação | ~1 s / 2,4 s / 230 quadros | componentes da base | senha direta, sem confete |

## 8. Trecho de referência: brasas

```dart
class _Brasa { double x, y, r, vy, vx, vida, max, fase; _Brasa(...); }

class BrasasPainter extends CustomPainter {
  BrasasPainter(this.brasas, this.tick) : super(repaint: tick);
  final List<_Brasa> brasas;      // alocadas UMA vez (90 no perfil high)
  final ValueListenable<int> tick; // incrementado por um Ticker
  final _p = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 1080;
    for (final b in brasas) {
      b.vida++; b.y -= b.vy; b.x += b.vx + math.sin((b.vida + b.fase * 50) / 40) * .5;
      final a = (1 - b.vida / b.max).clamp(0.0, 1.0);
      if (a <= 0 || b.y < 200) { b.renascer(); continue; }
      final centro = Offset(b.x * k, b.y * k);
      _p.shader = ui.Gradient.radial(centro, b.r * 4 * k, [
        Color.fromARGB((255 * a).round(), 255, 214, 140),
        Color.fromARGB((178 * a).round(), 255, 120, 40),
        const Color(0x00FF5014),
      ], const [0, .35, 1]);
      c.drawCircle(centro, b.r * 4 * k, _p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}
```

## 9. Paleta recomendada no admin (`PALETA_PRESET.brasa2`)

```ts
brasa2: { corPrimaria: '#EC7433', corDestaque: '#F4B63F', corFundo: '#120E0C', corPainel: '#1E1815', raio: 22 },
```

## 10. Checklist de aceite

- [ ] `templateDe` devolve `Brasa2Template` para `brasa2`, e `brasa` continua no visual antigo.
- [ ] As 8 telas + venda não concluída conferem com os PNG (layout, cores, tipografia e hierarquia).
- [ ] O descanso usa `descansoMidias`, `chamada`, `precoIsca`, `logoUrl` e `nomeLoja` quando existem.
- [ ] Comer aqui / Para levar gravam `consumo` e o seletor do carrinho vem marcado.
- [ ] Portões de papel/offline aparecem por cima do descanso Brasa.
- [ ] Todas as animações da seção 7 funcionando, e as versões estáticas com `animacoes: off`, `reduzido` e perfil `low` (sem brasas nem confete).
- [ ] Grupos obrigatórios, opções indisponíveis e produto esgotado se comportam como no GoGen.
- [ ] Identificação em 2 etapas, CPF validado, aviso de CPF obrigatório bloqueia **Pular**.
- [ ] Pagamento: escolha, PIX, Point, processando, erro e bloqueado.
- [ ] Confirmação com `dinheiro`, `impresso=false` e `fiscal=false` corretos.
- [ ] Sem overflow em 1080×1920 e em 800×600, `flutter analyze --fatal-infos` limpo e `flutter test` verde.
- [ ] Fontes DM Serif Display e Manrope empacotadas com OFL, e o tamanho informado no PR.
