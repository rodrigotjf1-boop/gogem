# 02 · Template **Vitrine** (`temaPreset: 'vitrine'`)

> Pré-requisito: Fase 0 do `00-base-templates.md`. Medidas em px de desenho sobre 1080 de largura (`context.dz`).

## 1. Conceito

O cardápio no formato de **stories**:
- Cada produto ocupa a tela inteira, com a foto em close.
- O cliente desliza para cima para ver o próximo produto.
- Textos e botões flutuam em **vidro fosco** por cima da comida.
- O descanso é uma sequência de stories com barras de progresso no topo.
- **Referências:** Instagram Stories, TikTok, iFood.
- **Ideal para:** lojas com **boas fotos** de produto e público jovem.

> Este é o template que mais depende da qualidade das fotos. Produto **sem foto** usa o fallback "disco de cor + recorte" (seção 6.2). Oriente o lojista a cadastrar fotos verticais ou quadradas de pelo menos 1080 px.

## 2. Mockups de referência

`mockups/02-vitrine/` (mesmos nomes de arquivo do 01). No `prototipo-interativo.html`, selecione **2. Vitrine**. No CSS, os seletores são `.t-vitrine`, `.att-vitrine`, `.menu-vitrine`, `.vcard`, `.pm-sheet`.

## 3. Tokens

```dart
const vitrineTokens = TemplateTokens(
  bg: Color(0xFF0A0A0A),
  surface: Color(0xFF181818),
  surface2: Color(0xFF262626),
  text: Color(0xFFFFFFFF),
  muted: Color(0xB3FFFFFF),      // branco 70%
  accent: Color(0xFFFF5B2E),     // laranja-tomate
  onAccent: Color(0xFFFFFFFF),
  accent2: Color(0xFFFFD23F),    // amarelo (preços, selos)
  onAccent2: Color(0xFF111111),
  line: Color(0x24FFFFFF),
  line2: Color(0x4DFFFFFF),
  price: Color(0xFFFFD23F),
  hi: Color(0x24FF5B2E),
  art: Color(0xFF1E1E1E),
  ok: Color(0xFF5EE08F),
  err: Color(0xFFFF6B5B),
  raio: 40, raioBotao: 999, raioTecla: 28,   // botões sempre pílula
  fonteDisplay: 'Syne',
  fonteTexto: 'Onest',
  pesoDisplay: FontWeight.w800,
);
/// Vidro: com blur → BackdropFilter(sigma 18–26) + Color(0x24FFFFFF) + borda Color(0x4DFFFFFF).
/// Sem blur (low/reduzido) → Color(0xD9161616) sólido + mesma borda.
const vitrineVidroSemBlur = Color(0xD9161616);
```

## 4. Tipografia

| Uso | Fonte | Tamanho |
|---|---|---|
| Nome no story do descanso | Syne 800 | 170, altura 0,86, espaçamento −0,04 em |
| Nome no card do feed | Syne 800 | 118, altura 0,9 |
| Títulos de tela | Syne 800 | 84, espaçamento −0,04 em |
| Preço no feed | Syne 800 | 64 `price` |
| Kicker | Onest 800 | 24–26 CAIXA ALTA, espaçamento 0,16 em |
| Corpo | Onest 400–600 | 28–30 |
| Botões | Onest 800 | 30–40 |

Logo padrão: "mordida" em Syne 800 58 com espaçamento −0,04 em e o ponto final na cor `accent`. Na loja, use o `nomeLoja` em minúsculas com o mesmo ponto `accent`, ou `logoUrl`.

## 5. Componentes

- **Botões:** pílula (raio 999). Primário com fundo `accent`. `glass` com vidro (seção 3), texto branco e borda de 2 px `0x4DFFFFFF`.
- **Chips de categoria:** altura 74, pílula, vidro. O selecionado ganha fundo branco e texto `0xFF111111`, com transição de 300 ms.
- **Selo:** pílula `accent2` com texto `onAccent2`, sem posição absoluta: fica **acima** do nome do produto.
- **Degradê de leitura** sobre as fotos: `[0: 0x8C000000, 0.22: 0, 0.44: 0, 0.80: 0xE6000000]` na vertical.

## 6. Telas

### 6.1 Descanso: stories (`01-descanso.png`)
- **Fonte dos slides:**
  - `descansoMidias` (até 6). Sem mídias, use os produtos com `selo` e foto.
  - Legenda do slide: `kicker` vira a pílula `accent2`, `titulo` vira o H1 170 (quebra de linha livre) e `subtitulo` vira o preço em vidro. Nos produtos, o selo vira o kicker, o nome vira o título e o preço vira `brl(precoCentavos)`.
- **Barras de progresso** no topo (top 28, laterais 56, espaço 10, altura 7, fundo `0x4DFFFFFF`):
  - A barra do slide atual enche em `intervaloSeg` com animação linear.
  - As anteriores ficam cheias e zeram ao recomeçar o ciclo.
- **Troca de slide:** crossfade de 1,2 s. A foto nova entra com Ken Burns de 9 s (escala 1,06 → 1,2).
- **Texto:** sai o anterior e entra o novo com fade + subida de 40 px em 700 ms, com atraso de 250 ms.
- **Logo** em top 74. Pílulas de idioma e acessível são Fase B.
- **Painel inferior de vidro:**
  - Raio superior 56, padding 40/56/72.
  - Contém "Toque para começar" e os botões xl **Comer aqui** (primário) e **Para levar** (vidro).

### 6.2 Catálogo: feed vertical (`02-cardapio.png`)
- **`PageView` vertical** em tela cheia com `PageScrollPhysics`, um produto por página (altura da tela), percorrendo as categorias em ordem.
- **Página com foto:**
  - Foto em cover com escala 1,04, degradê de leitura e texto ancorado a 260 do rodapé.
  - Conteúdo do texto: `Selo`, nome da categoria (kicker), nome em Syne 118, descrição 30 e linha com preço `accent2` 64 à esquerda.
  - Botões: **Personalizar** (vidro, abre o produto) e **+ Adicionar** (primário: adiciona direto se não houver etapa obrigatória, senão abre o produto).
- **Página sem foto:** fundo `0xFF141414` com disco `accent` de 900 (em 90, 360) e a foto `recorte` (840×700) flutuando ±18 px em 3,6 s. Se a imagem não existir, use o ícone de prato grande em `onAccent`.
- **Topo sobreposto:** degradê `0xB8000000 → transparente`, `Etapas(0)` com texto branco e os botões em vidro.
  - Embaixo ficam os **chips de categoria** roláveis na horizontal. Tocar leva ao 1º produto da categoria com `animateToPage` (450 ms, `easeOutCubic`), e a página atual marca o chip.
- **Esgotado:** página em cinza com o botão "Esgotado" desabilitado. Pular produtos esgotados também é aceitável: **decida e documente no PR**.
- **`BarraSacola` flutuante** sobre o feed: vidro, borda `0x2EFFFFFF`, botão interno "Ver sacola" `accent`.
- **Indicação de rolagem:** na 1ª abertura, uma seta para cima pulsa 3 vezes acima da barra ("Deslize para ver mais"). Não aparece com `anima=false`.

### 6.3 Produto (`03-produto.png`)
- **Folha de vidro** (top 140, raio superior 56) sobre a foto do produto desfocada no fundo, ou escurecida quando não há blur.
- **Topo da folha:** a foto (cover, 500 de altura, Ken Burns de 12 s) com o X em vidro.
- **Corpo:** nome em Syne 800 78 e preço 46 `price`. Os grupos seguem os cards da base, com raio 32 e seleção `accent` + fundo `hi`.
- **Rodapé:** `Quantidade` e **Adicionar · R$** em pílula `accent`.

### 6.4 Carrinho (`04-sacola.png`)
Fundo `bg`. É a mesma estrutura da base, com estas diferenças:
- Títulos em Syne 800.
- Lista em `surface` com raio 40.
- Bloco "Combina com seu pedido" em `surface2` com raio 40 e cards de sugestão com foto em cover.
- Total em Syne 800 78.

### 6.5 Peça também (`05-sugestao-sobremesa.png`)
Cartão central `surface2` com raio 50 e título em Syne 800. Os botões são pílula.

### 6.6 Identificação (`06`, `07`)
Mesma estrutura da base:
- Campos com raio 40 e fundo `surface`.
- Teclas com raio 28, fundo `surface` e sombra inferior `line`.
- Botões pílula.

### 6.7 Pagamento (`08`, `09`, `10`)
- **Opções:** raio 40.
- **Pix em destaque:** borda `accent` e fundo `hi`, com o ícone num quadrado `accent`.
- **Nomes:** Syne 800 46.
- **PIX e Point:** iguais à base, com cantos do QR, varredura e cartão da maquininha em `accent`.

### 6.8 Confirmação (`11-confirmado.png`)
- Check `accent` de 190.
- "Pedido confirmado!" em Syne 800 88.
- Senha em Syne 800 170 `accent`.
- Confete `[accent, accent2, branco]`.

## 7. Animações

| Animação | Onde | Duração / curva | Implementação | Reduzido / `low` / off |
|---|---|---|---|---|
| Barras de progresso | descanso | `intervaloSeg`, linear | `AnimationController` por slide + `FractionallySizedBox` | com `off`: barras estáticas e troca a cada `intervaloSeg` sem crossfade |
| Crossfade + Ken Burns | descanso | 1,2 s + 9 s | `AnimatedSwitcher` + `Transform.scale` | só crossfade (reduzido) ou troca seca (off) |
| Texto do slide | descanso | 700 ms, atraso 250 ms | `SlideTransition` + `FadeTransition` | instantâneo |
| Snap do feed | catálogo | física de página | `PageView(scrollDirection: Axis.vertical)` | igual |
| Recorte flutuando | feed sem foto | 3,4–3,6 s `easeInOut` | `Transform.translate` | parado |
| Vidro fosco | topo, barra, folha, descanso | — | `BackdropFilter` **só com `caps.enableBlur`** | `vitrineVidroSemBlur` |
| Folha do produto | produto | 500 ms `Cubic(.2,.9,.2,1)` | rota com `SlideTransition` | instantâneo |
| Voo + bump, senha, recibo, confete | base | — | base | base |
| Troca de tela | todas | zoom 1,06 → 1 + fade, 550 ms | transição de página | instantâneo |

## 8. Trecho de referência: barras de progresso

```dart
Row(children: [
  for (var i = 0; i < n; i++) ...[
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: context.dz(7),
          color: const Color(0x4DFFFFFF),
          alignment: Alignment.centerLeft,
          child: i < atual
              ? const SizedBox.expand(child: ColoredBox(color: Colors.white))
              : i == atual
                  ? AnimatedBuilder(
                      animation: progresso, // controller de intervaloSeg
                      builder: (_, __) => FractionallySizedBox(
                          widthFactor: progresso.value,
                          child: const ColoredBox(color: Colors.white)),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    ),
    if (i < n - 1) SizedBox(width: context.dz(10)),
  ],
]);
```

## 9. Paleta recomendada no admin (`PALETA_PRESET.vitrine`)

```ts
vitrine: { corPrimaria: '#FF5B2E', corDestaque: '#FFD23F', corFundo: '#0A0A0A', corPainel: '#181818', raio: 32 },
```

## 10. Checklist de aceite

- [ ] Descanso em stories com barras, usando `descansoMidias` e legendas, e com produtos com `selo` como fallback.
- [ ] O feed vertical encaixa um produto por tela, e os chips pulam para a categoria e acompanham a rolagem.
- [ ] Produto sem foto aparece com disco + recorte ou ícone, sem retângulo quebrado.
- [ ] Nenhum `BackdropFilter` quando `caps.enableBlur == false`: verificar com `GOGEM_HW_PROFILE=low`.
- [ ] **Personalizar** e **+ Adicionar** respeitam etapas obrigatórias.
- [ ] As demais telas conferem com os PNG, com os mesmos estados do 00 (seção 4).
- [ ] Animações com `off` e `reduzido` conforme a tabela.
- [ ] Testes do 00 (seção 5) + teste de navegação do feed (chip → página certa) sem `pumpAndSettle`.
- [ ] Fontes Syne e Onest empacotadas com OFL.
