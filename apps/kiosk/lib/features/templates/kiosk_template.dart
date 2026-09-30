import 'package:flutter/widgets.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_models.dart';
import 'brasa2/brasa2_template.dart';
import 'diner/diner_template.dart';
import 'movimento.dart';
import 'neon/neon_template.dart';
import 'template_tokens.dart';
import 'vitrine/vitrine_template.dart';

/// Contrato de APRESENTAÇÃO de um template do totem (docs/templates/00 §3.2).
///
/// A LÓGICA continua nas telas (`features/pedido/*`, descanso, catálogo): carrinho, portões
/// de impressora, TEF/Point, PIX, fiscal, idempotência, inatividade e venda não concluída
/// não mudam. O template só desenha — como a GoGen já faz. As *props* repetem os parâmetros
/// que as Views GoGen recebem, então nenhuma regra sai das telas.
abstract class KioskTemplate {
  const KioskTemplate();

  TemplateTokens get tokens;

  /// Fundo animado do descanso. Os portões (papel/offline) e o canto admin continuam
  /// sendo desenhados pela `DescansoScreen` POR CIMA disto.
  Widget descanso(DescansoProps p);

  /// Telas inteiras: leem os providers (cardápio, sacola) como a GoGen faz.
  Widget catalogo();
  Widget carrinho();

  Widget produto(ProdutoProps p);
  Widget pecaTambem(PecaTambemProps p);
  Widget identificacao(IdentificacaoProps p);
  Widget pagamento(PagamentoProps p);
  Widget sucesso(SucessoProps p);
}

/// Templates registrados. Cada PR de template acrescenta a sua linha; chave fora daqui
/// (`brasa`, `gogen`, `burger`, e a `padrao` antiga) segue o caminho atual das telas.
const Map<String, KioskTemplate> _registro = {
  'brasa2': Brasa2Template(),
  'neon': NeonTemplate(),
  'diner': DinerTemplate(),
  'vitrine': VitrineTemplate(),
};

Map<String, KioskTemplate>? _registroDeTeste;

/// Troca o registro num teste (ex.: um template falso para provar a delegação das telas).
/// `null` volta ao registro real.
@visibleForTesting
set registroDeTeste(Map<String, KioskTemplate>? r) => _registroDeTeste = r;

/// O template da loja, ou `null` quando o estilo não é um dos templates novos.
KioskTemplate? templateDe(Aparencia ap) => (_registroDeTeste ?? _registro)[ap.temaPreset];

/// Chaves já registradas (para teste e diagnóstico).
Iterable<String> get templatesRegistrados => _registro.keys;

class DescansoProps {
  const DescansoProps({
    required this.chamada,
    required this.mov,
    required this.bloqueado,
    required this.onIniciar,
    this.nomeLoja,
    this.logoUrl,
    this.precoIsca,
    this.midias = const [],
    this.intervaloSeg = 6,
    this.destaques = const [],
  });

  final String? nomeLoja;
  final String? logoUrl;

  /// `ap.chamada` ("Toque para começar" por padrão).
  final String chamada;
  final String? precoIsca;

  /// Mídias da loja (`descansoMidias`), já só as com URL.
  final List<DescansoMidia> midias;
  final int intervaloSeg;

  /// Produtos com selo, disponíveis, na ordem do cardápio — a "arte padrão" quando a loja
  /// não tem mídias (foto do mais vendido, letreiro de ofertas).
  final List<Produto> destaques;

  final Movimento mov;

  /// Portão de papel/offline fechado: o template para de pulsar e esmaece os botões; a
  /// tela desenha o aviso por cima.
  final bool bloqueado;

  /// Começa o pedido com o consumo escolhido: `'local'` (Comer aqui) ou `'viagem'`.
  /// Toque fora dos botões começa com `'local'`. Não faz nada quando [bloqueado].
  final void Function(String consumo) onIniciar;
}

class ProdutoProps {
  const ProdutoProps({
    required this.produto,
    required this.selecoes,
    required this.qtd,
    required this.valido,
    required this.totalCentavos,
    required this.onToggle,
    required this.onMenos,
    required this.onMais,
    required this.onAdicionar,
    required this.onVoltar,
    this.mov = Movimento.parado,
  });

  final Produto produto;
  final Map<String, List<OpcaoComplemento>> selecoes;
  final int qtd;
  final bool valido;
  final int totalCentavos;
  final void Function(GrupoComplemento, OpcaoComplemento) onToggle;
  final VoidCallback onMenos;
  final VoidCallback onMais;
  final VoidCallback onAdicionar;
  final VoidCallback onVoltar;
  final Movimento mov;
}

class PecaTambemProps {
  const PecaTambemProps({
    required this.sugeridos,
    required this.onAdicionar,
    required this.onVoltar,
    required this.onContinuar,
    this.mov = Movimento.parado,
  });

  final List<Produto> sugeridos;
  final void Function(Produto) onAdicionar;
  final VoidCallback onVoltar;
  final VoidCallback onContinuar;
  final Movimento mov;
}

class IdentificacaoProps {
  const IdentificacaoProps({
    required this.nomeController,
    required this.cpf,
    required this.completo,
    required this.valido,
    required this.onDigito,
    required this.onApagar,
    required this.onPular,
    required this.onConfirmar,
    required this.onVoltar,
    this.avisoCpfObrigatorio,
    this.mov = Movimento.parado,
  });

  /// Não-nulo: esta compra PRECISA do CPF (limite da UF) — "Pular" fica desabilitado.
  final String? avisoCpfObrigatorio;
  final TextEditingController nomeController;
  final String cpf;
  final bool completo;
  final bool valido;
  final void Function(String) onDigito;
  final VoidCallback onApagar;
  final VoidCallback onPular;
  final VoidCallback onConfirmar;
  final VoidCallback onVoltar;
  final Movimento mov;
}

class PagamentoProps {
  const PagamentoProps({
    required this.totalCentavos,
    required this.bloqueado,
    required this.motivo,
    required this.processando,
    required this.erro,
    required this.pointAtivo,
    required this.pixCopiaECola,
    required this.pixContador,
    required this.onVoltar,
    required this.onVoltarCarrinho,
    required this.onTentarNovamente,
    required this.onPagarPix,
    required this.onPagarCartao,
    required this.onPagarDinheiro,
    required this.onCancelarPix,
    required this.onCancelarPoint,
    this.mensagemProcessando,
    this.cliente = '',
    this.mov = Movimento.parado,
  });

  final int totalCentavos;
  final bool bloqueado;
  final String motivo;
  final bool processando;
  final String? erro;
  final bool pointAtivo;

  /// Não-nulo = tela do PIX.
  final String? pixCopiaECola;

  /// Contador do PIX em mm:ss.
  final String pixContador;
  final VoidCallback onVoltar;
  final VoidCallback onVoltarCarrinho;
  final VoidCallback onTentarNovamente;
  final VoidCallback onPagarPix;
  final VoidCallback onPagarCartao;
  final VoidCallback onPagarDinheiro;
  final VoidCallback onCancelarPix;
  final VoidCallback onCancelarPoint;
  final String? mensagemProcessando;

  /// Nome digitado na identificação (vazio = não informou) — vai no kicker "Último passo".
  final String cliente;
  final Movimento mov;
}

class SucessoProps {
  const SucessoProps({
    required this.senha,
    required this.impresso,
    required this.entrada,
    required this.onNovoPedido,
    this.dinheiro = false,
    this.segundos = 0,
    this.fiscal = true,
    this.mov = Movimento.parado,
  });

  final String senha;
  final bool impresso;

  /// 0..1 — progresso da entrada/impressão (o mesmo que a GoGen recebe).
  final double entrada;
  final VoidCallback onNovoPedido;

  /// Pedido em dinheiro: "Dirija-se ao caixa para pagar".
  final bool dinheiro;

  /// Segundos até voltar ao início.
  final int segundos;

  /// `false` = a NFC-e foi emitida mas o DANFE não saiu no papel (ERR-022).
  final bool fiscal;
  final Movimento mov;
}
