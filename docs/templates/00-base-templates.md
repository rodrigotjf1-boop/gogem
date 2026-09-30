# 00 · Base comum dos templates do totem GoGeM

> Documento de engenharia para o Claude Code. Leia inteiro antes de mexer no código. Os 5 arquivos de template (`01` a `05`) **dependem** deste.

## 1. Objetivo

Adicionar 5 templates de autoatendimento ao totem, selecionáveis por loja em **Configurações → Aparência → Estilo do totem** no admin:

| Chave | Nome no admin | Identidade |
|---|---|---|
| `brasa2` | Brasa 2.0 (steakhouse com fogo) | escuro, laranja brasa, serifa |
| `vitrine` | Vitrine (cardápio em stories) | fotos em tela cheia, vidro fosco |
| `estudio` | Estúdio (clean, produtos flutuando) | claro, azul + amarelo, geométrico |
| `neon` | Neon 2.0 (noite urbana) | preto, verde-limão + magenta, néon |
| `diner` | Diner 58 (lanchonete anos 50) | creme, vermelho + menta, letreiro com lâmpadas |

Cada template muda **layout e movimento**, não só cores, como o template GoGen já faz hoje. **A regra de negócio do fluxo não muda:** carrinho, portões de impressora, TEF/Point, PIX, fiscal, idempotência, inatividade e venda não concluída continuam exatamente como estão.

> Sobre o `brasa` antigo: o preset `brasa` que já existe (editorial, só tipografia e cores) **continua funcionando**. O novo recebe a chave `brasa2` para não mudar a cara de lojas que já usam `brasa`.

## 2. Como o código está hoje (levantado do repositório)

- O app do totem fica em `apps/kiosk` (Flutter, Riverpod, go_router). As rotas estão em `lib/core/router.dart`:
  `/descanso → /catalogo → /produto/:id → /carrinho → /peca-tambem → /identificacao → /pagamento → /confirmacao` (e `/nao-concluida`).
- A aparência vem de `lib/data/catalog/aparencia.dart` (`Aparencia.fromJson`, sincronizada com o catálogo publicado). Os campos usados pelos templates são:
  - `temaPreset`, `nomeLoja`, `logoUrl`, `chamada`, `precoIsca`
  - `descansoMidias` (url + kicker/título/subtítulo), `descansoIntervaloSeg`
  - `animacoes` (`cheio` | `reduzido` | `off`)
- O **template GoGen** é o precedente a seguir. Quando `ap.gogen` está ligado, cada tela delega a apresentação para uma *View* em `lib/features/gogen/`:

  | Tela (lógica fica aqui) | Delegação GoGen hoje |
  |---|---|
  | `features/descanso/descanso_screen.dart` | `GogenStandby(...)` como fundo; os portões e o canto do admin continuam na tela |
  | `features/catalogo/catalogo_screen.dart` | `return const GogenCatalogoScreen()` (tela inteira, lê providers) |
  | `features/pedido/produto_screen.dart` | `GogenProdutoView(produto, selecoes, qtd, valido, totalCentavos, onToggle, onMenos, onMais, onAdicionar, onVoltar)` |
  | `features/pedido/carrinho_screen.dart` | `return const GogenCarrinhoScreen()` (inclui o seletor de consumo local/viagem) |
  | `features/pedido/peca_tambem_screen.dart` | `GogenPecaTambemView(sugeridos, onAdicionar, onVoltar, onContinuar)` |
  | `features/pedido/identificacao_screen.dart` | `GogenIdentificacaoView(avisoCpfObrigatorio, nomeController, cpf, completo, valido, onDigito, onApagar, onPular, onConfirmar, onVoltar)` |
  | `features/pedido/pagamento_screen.dart` | `GogenPagamentoView(totalCentavos, bloqueado, motivo, processando, erro, pointAtivo, pixCopiaECola, pixContador, mensagemProcessando, onVoltar, onVoltarCarrinho, onTentarNovamente, onPagarPix, onPagarCartao, onPagarDinheiro, onCancelarPix, onCancelarPoint)` |
  | `features/pedido/confirmacao_screen.dart` | `GogenSucessoView(senha, impresso, entrada, dinheiro, segundos, fiscal, onNovoPedido)` |
  | `features/pedido/venda_nao_concluida_screen.dart` | troca só as cores (fundo, tinta, tinta2, alerta) |

- **Modelos:**
  - `Produto`: `nome`, `descricao`, `precoCentavos`, `disponivel`, `imagemUrl`, `selo`, `grupos`, `upsell`.
  - `GrupoComplemento`: `min`, `max`, `obrigatorio`.
  - `OpcaoComplemento`: `precoCentavosDelta`, `disponivel`.
  - `Categoria`: `imagemUrl`, `emoji`, `cor`.
  - Outros: `Carrinho` / `ItemCarrinho`, `CheckoutState` (`cpf`, `consumo` `local|viagem`, `cliente`) e `FormaPagamento { credito, debito, pix, vr, dinheiro }`.
- **Desempenho:** `HardwareCaps` (`enableBlur`, `enableParticles`, `animationScale`). O Tinker Board (perfil `low`) **não tem blur nem partículas** e usa animação a 60%. `animacoes: reduzido` equivale a `caps.reduzidas`, e `off` desliga tudo.
- **Inatividade:** `InatividadeGuard` volta ao descanso após 90 s sem toque, e nunca durante uma venda.

> **Antes de começar, confirme cada ponto acima no código atual.** Se algo mudou desde este levantamento (nome de parâmetro, rota, provider), siga o código e anote a diferença na descrição do PR.

## 3. Fase 0 — base comum (PR 1)

### 3.1 Aparência: novas chaves

`lib/data/catalog/aparencia.dart`:

```dart
bool get brasa2  => temaPreset == 'brasa2';
bool get vitrine => temaPreset == 'vitrine';
bool get estudio => temaPreset == 'estudio';
bool get neon    => temaPreset == 'neon';
bool get diner   => temaPreset == 'diner';
```

Não mude `editorial` (continua `brasa || burger`).

### 3.2 Registro de templates (evitar 6 `if` por tela)

Crie `lib/features/templates/kiosk_template.dart` com um contrato único e um resolvedor. As *props* repetem **exatamente** os parâmetros que as Views GoGen já recebem. Assim nenhuma lógica sai das telas.

```dart
/// Contrato de apresentação de um template do totem. A LÓGICA continua nas telas
/// (features/pedido/*, descanso, catálogo); o template só desenha.
abstract class KioskTemplate {
  const KioskTemplate();
  TemplateTokens get tokens;

  /// Fundo animado do descanso. Os portões (papel/offline) e o canto admin
  /// continuam sendo desenhados pela DescansoScreen POR CIMA disto.
  Widget descanso(DescansoProps p);

  /// Telas inteiras (leem providers como a GoGen faz hoje).
  Widget catalogo();
  Widget carrinho();

  Widget produto(ProdutoProps p);
  Widget pecaTambem(PecaTambemProps p);
  Widget identificacao(IdentificacaoProps p);
  Widget pagamento(PagamentoProps p);
  Widget sucesso(SucessoProps p);
}

KioskTemplate? templateDe(Aparencia ap) => switch (ap.temaPreset) {
      'brasa2' => const Brasa2Template(),
      'vitrine' => const VitrineTemplate(),
      'estudio' => const EstudioTemplate(),
      'neon' => const NeonTemplate(),
      'diner' => const DinerTemplate(),
      _ => null, // padrao/brasa/burger/gogen seguem o caminho atual
    };
```

- `ProdutoProps`, `PecaTambemProps`, `IdentificacaoProps`, `PagamentoProps` e `SucessoProps` são classes imutáveis com os mesmos campos e callbacks das Views GoGen listadas na seção 2.
- `DescansoProps` tem:
  - dados da loja: `nomeLoja`, `logoUrl`, `chamada`, `precoIsca`, `midias`, `intervaloSeg`
  - flags de movimento: `anima`, `particulas`, `blur`, `escalaAnimacao`
  - `bloqueado`
  - `onIniciar(String consumo)`, que recebe `'local'` ou `'viagem'`

Em cada tela, logo depois do `if (ap.gogen)` existente:

```dart
final tpl = templateDe(ap);
if (tpl != null) return tpl.produto(ProdutoProps(/* mesmos valores passados à GoGen */));
```

- **Descanso:**
  - Coloque `tpl.descanso(...)` no lugar do fundo, como a GoGen faz. Os overlays de portão e o canto admin ficam por cima.
  - `onIniciar(consumo)` executa `ref.read(checkoutProvider.notifier).setConsumo(consumo)` e depois `context.go('/catalogo')`, sem fazer nada quando `bloqueado`.
  - Toque em qualquer área fora dos botões inicia com `local`, que é o comportamento atual.
- **Venda não concluída:** use `tpl.tokens` para fundo, tinta, tinta2 e alerta, igual ao que a GoGen faz com as cores dela.

> Não é obrigatório migrar a GoGen para o registro neste PR. Se migrar, faça em commit separado e mantenha os testes GoGen verdes.

### 3.3 Tokens e escala

`lib/features/templates/template_tokens.dart`:

```dart
class TemplateTokens {
  const TemplateTokens({
    required this.bg, required this.surface, required this.surface2,
    required this.text, required this.muted,
    required this.accent, required this.onAccent,
    required this.accent2, required this.onAccent2,
    required this.line, required this.line2, required this.price,
    required this.hi,      // fundo de item selecionado (tint do acento)
    required this.art,     // fundo atrás de fotos
    required this.ok, required this.err,
    required this.raio, required this.raioBotao, required this.raioTecla,
    required this.fonteDisplay, required this.fonteTexto,
    this.pesoDisplay = FontWeight.w400,
    this.displayCaixaAlta = false,
    this.claro = false,   // Estúdio e Diner são claros
  });
  // …campos finais…
}
```

- **Cores:** cada template define as suas em `Color(0xFFRRGGBB)` const.
- **Proibido `withOpacity` e `withValues`** (regra do `CLAUDE.md`). Alfa fixo vai como `Color(0xAARRGGBB)` e alfa dinâmico com `withAlpha(...)`.
- **Escala (`lib/features/templates/escala.dart`):** todas as medidas deste pacote estão em **px de desenho sobre uma tela de 1080 de largura** (retrato 1080×1920).

```dart
extension Escala on BuildContext {
  double get k => MediaQuery.sizeOf(this).width / 1080.0;
  double dz(num px) => px * k;   // uso: context.dz(34)
}
```

- **Telas baixas:** conteúdo que pode não caber (harness de teste 800×600 e totem Windows em paisagem) fica em `SingleChildScrollView` ou `Flexible`. **Nunca pode dar overflow.**

### 3.4 Movimento que respeita o hardware

`lib/features/templates/movimento.dart`: um `Movimento` resolvido uma vez por tela a partir de `ap` e `hardwareCapsProvider`.

```dart
class Movimento {
  final bool anima;          // false quando animacoes == 'off'
  final bool particulas;     // caps.enableParticles && !reduzido
  final bool blur;           // caps.enableBlur
  final double escala;       // caps.animationScale (1.0 ou 0.6)
  Duration d(int ms) => Duration(milliseconds: (ms / escala).round());
}
```

Regras obrigatórias, válidas em todos os templates:

1. **`anima == false`:** nenhum `AnimationController.repeat()` é criado. Mostre o quadro final estático.
2. **`particulas == false`:** sem brasas, confete, faixas correndo ou lâmpadas piscando. Use a versão estática descrita em cada template.
3. **`blur == false`:** nada de `BackdropFilter`. Troque o vidro fosco por cor sólida translúcida.
4. **Ken Burns** (zoom lento em foto): só com `anima`. Use `Transform.scale` num `AnimatedBuilder`, nunca imagem maior recortada a cada quadro.
5. **Partículas** vão num único `CustomPainter` com lista fixa de partículas (sem alocar por quadro). No máximo 90 no perfil `high`.
6. **Controllers:** `dispose()` sempre. Nada de `Timer.periodic` sem cancelar.
7. **Imagens:** sempre `ProdutoImagem` / `CachedNetworkImage`, com `memCacheWidth` no tamanho exibido (a RAM é de 2 GB).

### 3.5 Componentes compartilhados (`lib/features/templates/comum/`)

Cada template estiliza estes componentes com os próprios tokens. A lógica fica aqui uma vez só:

| Componente | Função |
|---|---|
| `ProdutoArte` | Mostra a foto do produto: `recorte` (contain + sombra projetada) quando a URL termina em `.png`, senão `foto` (cover no recipiente). Sem URL, usa o placeholder do `ProdutoImagem`. |
| `Selo` | Pílula do `produto.selo` ("Mais pedido" e similares). Indisponível: selo "Esgotado" e card em cinza (matriz de saturação 0) sem toque. |
| `Etapas` | Barra de 4 passos (Cardápio, Sacola, Identificação, Pagamento). Barra de 8 px, passo atual preenche em 800 ms, concluídos com ✓. |
| `BarraSacola` | Barra inferior do catálogo: ícone da sacola com contador, "Sua sacola · N itens", total e botão "Ver sacola". Anima **bump** (escala 1 → 1,04 → 0,98 → 1, 500 ms) quando o total muda. |
| `VooParaSacola` | Ao adicionar, uma cópia da foto voa em curva até a barra (820 ms, `Curves.easeInOutCubic`, escala 1 → 0,12) via `Overlay`. Desligado com `!anima`. |
| `Quantidade` | − n + com alvos ≥ 72 px de desenho. |
| `TecladoCpf` | Teclado numérico 3×4 (1–9, Limpar, 0, Apagar). Máscara `000.000.000-00`. Borda verde com CPF válido; vermelha com tremida (400 ms) se inválido com 11 dígitos. |
| `TecladoNome` | Teclado QWERTY com Ç, apagar e espaço, escrevendo no `nomeController` existente. O `TextField` fica `readOnly: true, showCursor: true` para o teclado do sistema não abrir. Máximo de 12 caracteres, sem dois espaços seguidos. |
| `QrPix` | `QrImageView` do `pixCopiaECola` num quadro branco, com cantos na cor do acento e linha de varredura subindo e descendo (2,2 s, só com `anima`). |
| `MaquininhaAnimada` | Ilustração de maquininha (desenhada em widgets, sem imagem) com cartão aproximando em loop (2,6 s). Mostrada quando `pointAtivo`. |
| `ContagemSenha` | A senha "conta" de 000 até o valor em cerca de 1 s. Sem `anima`, mostra direto. |
| `ReciboImpresso` | Recibo que "sai" da fenda (2,4 s, em degraus). Só quando `impresso == true`. |
| `Confete` | `CustomPainter`, 170 peças, gravidade 0,55, 230 quadros. Só com `particulas`. |
| `sugestoesUpsell(carrinho, menu)` | Extraia para `domain/order/` a função que hoje vive em `peca_tambem_screen.dart` (`_sugeridos`: upsell dos itens, na ordem, sem repetir, disponível e fora do carrinho). A tela de carrinho dos templates usa a mesma função no bloco "Combina com seu pedido". |

### 3.6 Fontes (offline-first)

As fontes são **empacotadas no app**, nunca baixadas em tempo de execução. Todas são OFL (Google Fonts):

| Template | Display | Texto | Extra |
|---|---|---|---|
| Brasa 2.0 | DM Serif Display (Regular, Italic) | Manrope (600, 700, 800) | — |
| Vitrine | Syne (700, 800) | Onest (400, 600, 800) | — |
| Estúdio | Sora (700, 800) | Figtree (400, 600, 800) | — |
| Neon 2.0 | Unbounded (700, 800) | Rubik (400, 600, 700) | — |
| Diner 58 | Bungee (Regular) | Nunito (600, 800, 900) | Yellowtail (Regular, cursiva) |

- **Onde ficam:** `apps/kiosk/assets/fonts/<Familia>/`, cada pasta com o `OFL.txt`, registradas no `pubspec.yaml` como a Tektur já é.
- **De onde baixar:** do repositório `github.com/google/fonts` (`ofl/<familia>/`). Se o ambiente não tiver rede, **pare e peça ao Rodrigo** os arquivos `.ttf`. Não use `google_fonts` nem fonte remota.
- **Peso:** baixe só os pesos listados e prefira os `.ttf` estáticos. Coloque o total de KB das fontes na descrição do PR.

### 3.7 API, contrato e admin

1. **API:** `apps/api/src/aparencia/dto/update-aparencia.dto.ts`, no `@IsIn` e no `@ApiPropertyOptional({ enum })` de `temaPreset`, acrescente `'brasa2', 'vitrine', 'estudio', 'neon', 'diner'`. O Prisma guarda `String`, então não precisa de migração. Adicione um teste de DTO aceitando as 5 chaves e recusando uma chave inválida.
2. **Contrato:** atualize o enum no OpenAPI de `packages/contracts` (regra 9 do `CLAUDE.md`). Não é quebra de compatibilidade.
3. **Admin:**
   - Em `apps/admin/src/lib/aparencia.ts`, amplie o tipo `temaPreset`.
   - Em `routes/configuracoes.tsx`, acrescente as 5 opções com os rótulos da tabela da seção 1.
   - Acrescente também as entradas em `PALETA_PRESET` (cores em cada arquivo de template, seção "Paleta recomendada no admin"). Assim as telas que ainda não têm variante ficam coerentes com o template.
   - Teste: selecionar o preset aplica a paleta.

### 3.8 Aceite da Fase 0

- [ ] Chaves novas no `Aparencia` + teste de `fromJson` para cada uma.
- [ ] `KioskTemplate`, props, `templateDe`, `TemplateTokens`, `Escala` e `Movimento` criados. Ainda **sem** template concreto (`templateDe` devolve `null` para todas as chaves até cada PR de template registrar o seu).
- [ ] Componentes de `templates/comum/` com testes de widget unitários (máscara e validação do CPF, limite do teclado de nome, `sugestoesUpsell`, `Movimento` com `off`, `reduzido` e `low`).
- [ ] Telas com o ponto de delegação `templateDe(ap)` (sem efeito enquanto for `null`).
- [ ] API, contrato e admin aceitando as 5 chaves.
- [ ] PRE-VOO verde: `flutter analyze --fatal-infos` e `flutter test`, além de `pnpm lint && pnpm typecheck` e os testes de API e admin.

## 4. O que cada tela precisa mostrar (vale para os 5 templates)

As medidas específicas estão em cada arquivo de template. Aqui fica o **conteúdo obrigatório** e os **estados** que nenhum template pode esquecer.

### 4.1 Descanso (`/descanso`)
- Logo (`logoUrl`) ou nome da loja (`nomeLoja`). Sem nenhum dos dois, use o nome do template.
- Chamada (`ap.chamada`, padrão "Toque para começar") com indicação de toque animada.
- Dois botões grandes: **Comer aqui** (`local`) e **Para levar** (`viagem`).
- **Mídias da loja** (`descansoMidias`) quando houver, trocando a cada `descansoIntervaloSeg`. `kicker`, `titulo` e `subtitulo` viram a legenda. Sem mídias, use a arte padrão do template (descrita em cada arquivo).
- **Preço-isca** (`precoIsca`) num selo quando houver.
- **Bloqueado:** os portões atuais da `DescansoScreen` continuam por cima. O template recebe `bloqueado` só para parar o pulsar e esmaecer os botões.

### 4.2 Catálogo (`/catalogo`)
- Topo com logo, as ações Acessível (Fase B; em Fase A, esconder), **Cancelar** (limpa o carrinho e o checkout e volta ao descanso, igual ao que já existe) e `Etapas(0)`.
- Navegação por categorias (`menu.categorias`, com `imagemUrl` ou `cor` ou inicial) e rolagem sincronizada: tocar numa categoria rola até a seção, e rolar marca a categoria visível.
- **Destaque** no topo: produtos com `selo` não nulo (até 4). Sem nenhum, use os 3 primeiros da primeira categoria.
- Card de produto com foto (`ProdutoArte`), `Selo`, nome, descrição (até 2 linhas), preço e botão +.
- Categoria pausada ou produto indisponível: aplique a `Disponibilidade` que já existe.
- Estados vazios do GoGen (carregando, sem snapshot, offline) com o visual do template.
- `BarraSacola` fixa embaixo.
- **Toque no card:** produto com etapa obrigatória (`minEfetivo(g) > 0`) abre `/produto/:id`. Sem etapa, o card abre `/produto/:id` e o botão + adiciona direto com `VooParaSacola`, com a mesma regra da peça-também.

### 4.3 Produto (`/produto/:id`)
- Foto grande, nome, descrição e preço base.
- Um bloco por `GrupoComplemento`:
  - Título com "Obrigatório" ou "Até N".
  - `max == 1` vira opção única (radio). Senão, múltipla, respeitando `max`.
  - Opção indisponível aparece desabilitada, com o preço `+ R$` do delta.
- Rodapé com `Quantidade` e botão **Adicionar · R$ total**, desabilitado quando `!valido`.
- **Voltar:** botão X no topo da foto.

### 4.4 Carrinho (`/carrinho`)
- Título, contagem de itens e lista de itens (foto, nome, complementos escolhidos em linhas pequenas, total da linha, lixeira e quantidade). Ao remover, a linha desliza para a esquerda e some (320 ms).
- **Seletor de consumo** (Comer aqui / Para levar) já vem marcado com o que foi escolhido no descanso. É o que o GoGen tem hoje.
- **Bloco "Combina com seu pedido":** até 3 itens de `sugestoesUpsell`, com foto, nome, preço e +. Some quando a lista está vazia.
- Rodapé com o total grande e os botões **Adicionar mais** (catálogo) e **Finalizar pedido**, que vai para `/peca-tambem` como hoje.

### 4.5 Peça também (`/peca-tambem`)
Apresente como o **cartão central do protótipo** ("Uma sobremesa pra fechar?"):
- Título, subtítulo e grade de até 3 sugestões com foto, nome, preço e + (item adicionado mostra ✓).
- Botão principal: **Seguir sem sugestão** enquanto nada foi adicionado, e **Continuar** depois.
- A lógica de pular quando não há sugestões continua na tela.

### 4.6 Identificação (`/identificacao`)
O contrato é uma View só, mas o template mostra **duas etapas internas** (estado local da View):
1. **CPF na nota?** com a pílula "Opcional", `TecladoCpf`, e os botões **Pular** e **Continuar** (este só habilitado com CPF vazio ou válido).
   - Com `avisoCpfObrigatorio != null`: esconda "Opcional", mostre o aviso em destaque e desabilite **Pular**.
   - Sair da etapa 1 **não** chama `onPular` nem `onConfirmar` ainda. Guarde a escolha.
2. **Como podemos te chamar?** com o campo do nome (placeholder "Digite seu nome", contador 0/12) e `TecladoNome`.
   - **Continuar para pagamento** chama `onConfirmar` (com CPF) ou `onPular` (sem CPF). O nome já está no `nomeController`.
   - **Voltar** na etapa 2 retorna à etapa 1. Na etapa 1, chama `onVoltar`.

### 4.7 Pagamento (`/pagamento`)
- **Escolha:**
  - Kicker "Último passo" (com o nome, se houver) e título "Como você quer pagar?".
  - Opções: **Pix** (em destaque, selo "Mais rápido"), **Cartão** ("Crédito, débito ou vale: você escolhe na maquininha") e **Dinheiro** ("Seu pedido vai para o caixa e você paga lá"). Mostre só as formas que a `GogenPagamentoView` mostra hoje e nas mesmas condições.
  - As opções entram em cascata (70 ms entre cada uma).
  - Resumo embaixo com o total.
- **PIX** (`pixCopiaECola != null`): `QrPix`, o total grande, o contador `pixContador` ("Expira em 04:59"), três pontos animados com "Aguardando pagamento" e o botão **Trocar forma de pagamento**, que chama `onCancelarPix`.
- **Cartão** (`pointAtivo`): `MaquininhaAnimada`, título "Use a maquininha abaixo", seta animada para baixo e o botão **Cancelar**, que chama `onCancelarPoint`.
- **Processando:** spinner com a `mensagemProcessando`, ou "Processando…" quando ela vier nula.
- **Erro:** mensagem `erro` com **Tentar novamente** e **Voltar**.
- **Bloqueado:** ícone de impressora, "Não é possível pagar agora", o `motivo`, "Chame um atendente, seu carrinho está salvo" e os botões **Voltar ao carrinho** e **Tentar novamente**.

### 4.8 Confirmação (`/confirmacao`)
- Selo de check grande com anel pulsando e o kicker "Pagamento aprovado". Com `dinheiro`, o kicker vira "Dirija-se ao caixa para pagar" e o ícone vira cédula.
- Título **Pedido confirmado!** (com `dinheiro`: **Pedido enviado!**).
- Cartão com "Sua senha" e a senha gigante (`ContagemSenha`).
- Se `fiscal == false`, mostre o aviso de retirar a nota no balcão, com o mesmo texto da GoGen.
- Se `impresso == false`, mostre o aviso de comprovante não impresso, com o mesmo texto da GoGen.
- `ReciboImpresso` quando `impresso`.
- `Confete`.
- Botão **Fazer novo pedido** e o texto "Voltando ao início em N s" (`segundos`).
- Nome do cliente: o `checkoutProvider` é limpo **antes** da confirmação, então em Fase A a frase é "Vamos chamar sua senha no painel". Em Fase B, passe `cliente` na query (seção 9).

### 4.9 Venda não concluída
Mantenha o texto e o comportamento atuais. Só aplique `tokens.bg`, `tokens.text`, `tokens.muted` e `tokens.err` (e a fonte display no título).

## 5. Testes obrigatórios por template

Arquivo `apps/kiosk/test/templates/<chave>_test.dart`. Siga os padrões de `test/gogen_flow_test.dart` e `test/fixtures.dart`.

- Monte cada View com `Movimento(anima: false, ...)` e **tela 1080×1920** (`tester.view.physicalSize = const Size(1080, 1920); tester.view.devicePixelRatio = 1;` com `addTearDown(tester.view.reset)`).
- Repita um caso por tela em **800×600** para garantir **ausência de overflow**.
- **Proibido `pumpAndSettle`.** Use `tester.pump(const Duration(milliseconds: 300))` em passos.
- Casos mínimos:
  - O descanso chama `onIniciar('viagem')` ao tocar em **Para levar**.
  - O descanso com `bloqueado` não chama nada.
  - O catálogo renderiza uma categoria e um produto da fixture, e produto indisponível não reage ao toque.
  - O produto com grupo obrigatório deixa **Adicionar** desabilitado até escolher.
  - O carrinho mostra o total e o bloco de sugestões quando `sugestoesUpsell` não está vazio.
  - A peça também chama `onAdicionar` e troca o rótulo para **Continuar**.
  - Identificação:
    - Com CPF inválido, **Continuar** fica desabilitado.
    - Com o aviso de obrigatório, **Pular** fica desabilitado.
    - A etapa 2 chama `onConfirmar` ou `onPular` corretamente.
  - O pagamento tem os estados escolha, PIX, Point, processando, erro e bloqueado, com as chaves `ValueKey` equivalentes às da GoGen (`forma-dinheiro` etc.).
  - O sucesso mostra a senha e os avisos de `impresso: false`, `fiscal: false` e `dinheiro: true`.
- Um teste de `templateDe(Aparencia.fromJson({'temaPreset': '<chave>'}))` devolvendo o template certo.

## 6. Mapa protótipo → GoGeM real

| No protótipo | No GoGeM (Fase A) |
|---|---|
| Fotos/recortes de exemplo | `produto.imagemUrl` (`ProdutoArte`: `.png` vira recorte, o resto vira foto) |
| Slides do descanso (Vitrine/Brasa) | `ap.descansoMidias` + `kicker`/`titulo`/`subtitulo` |
| "Combo Duplo Bacon R$ 52,90" no selo | `ap.precoIsca` |
| Tags "Mais pedido", "Novo" | `produto.selo` (texto livre do lojista) |
| Item esgotado | `produto.disponivel == false` / `Disponibilidade` |
| Combo com acompanhamento e bebida | `GrupoComplemento` que o lojista cadastra no produto |
| "Combina com seu pedido" e sobremesa | `produto.upsell` → `sugestoesUpsell` (carrinho + peça também) |
| Crédito / Débito separados | **Cartão** único, a maquininha escolhe |
| "Simular aprovação" | **não existe**, a confirmação vem do PSP |
| Idiomas PT/EN/ES, acessível, aviso de inatividade | Fase B (seção 9) |
| "Pedido enviado à cozinha · Regem" | exibir só se o fluxo atual já tiver essa confirmação; senão omitir |

## 7. Regras do repositório que valem aqui (do `CLAUDE.md`)

- Cor: `withAlpha` / `Color(0xAARRGGBB)`. Nunca `withOpacity` ou `withValues`.
- Sem `pumpAndSettle` com `repeat()` na árvore. O harness é 800×600.
- Warning novo no analyze deve ser corrigido, nunca suprimido.
- Nada de WebView nem biblioteca de UI pesada: tudo em widgets e `CustomPainter`.
- PRs pequenos, em PT-BR, com teste e checklist.
- PRE-VOO: `cd apps/kiosk && flutter pub get && flutter analyze --fatal-infos && flutter test`.

## 8. Estrutura de pastas final

```
apps/kiosk/lib/features/templates/
├── kiosk_template.dart        (contrato + templateDe + props)
├── template_tokens.dart
├── escala.dart
├── movimento.dart
├── comum/                     (componentes da seção 3.5)
├── brasa2/   (brasa2_template.dart, brasa2_tokens.dart, descanso.dart, catalogo.dart, produto.dart, carrinho.dart, peca_tambem.dart, identificacao.dart, pagamento.dart, sucesso.dart, pintores/)
├── vitrine/  (mesma estrutura)
├── estudio/
├── neon/
└── diner/
apps/kiosk/assets/fonts/<Familia>/*.ttf + OFL.txt
apps/kiosk/test/templates/<chave>_test.dart
```

## 9. Fase B — recursos novos do protótipo (cada um é um PR separado)

Nenhum destes itens é necessário para os templates funcionarem. Todos exigem mudança em API + contrato + admin + kiosk e precisam de aprovação antes.

1. **Transformar em combo com um toque.**
   - Campo `produto.comboSugerido { produtoComboId | grupoId, precoExtraCentavos, economiaCentavos }` no catálogo publicado e no admin (diálogo do produto).
   - No produto: cartão "Transforme em combo" com interruptor (visual no protótipo).
   - Depois de adicionar um lanche sem combo: diálogo "Que tal fazer combo?" (**Quero combo** / **Não, obrigado**) que troca a linha do carrinho.
2. **Imagem nas opções de complemento.** `OpcaoComplemento.imagemUrl` opcional (ou referência a um produto), para os cards com foto de acompanhamento e bebida do protótipo.
3. **Foto recortada explícita.** Flag `produto.imagemRecortada` no admin, no lugar da heurística `.png`.
4. **Aviso de inatividade.** Aos 75 s parado, diálogo "Ainda está aí?" com anel de 15 s, **Continuar pedido** e **Cancelar pedido**. Ao zerar, faz o que o `InatividadeGuard` já faz. Estende o guard com o callback `aoAvisar`.
5. **Idiomas PT/EN/ES.** i18n do kiosk (`flutter_localizations` + ARB) e pílulas no descanso e no topo. Nomes de produto continuam no idioma do catálogo.
6. **Modo acessível.** Botão no topo e no descanso que desce todo o conteúdo interativo para a metade inferior da tela (faixa superior de 600 px de desenho com o aviso "Modo acessível ativado"), para cadeirantes e crianças.
7. **Nome na confirmação.** Passar `cliente` na query de `/confirmacao` antes de limpar o checkout, para mostrar "Vamos chamar **ANA** no painel".
8. **Selos padronizados.** Enum opcional `produto.seloTipo` (`mais_pedido`, `novo`, `vegetariano`, `promo`) para colorir o selo por tipo, mantendo `selo` como texto.
