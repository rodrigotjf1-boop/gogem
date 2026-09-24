import 'package:go_router/go_router.dart';
import 'pareamento/device_token.dart';
import '../features/descanso/descanso_screen.dart';
import '../features/catalogo/catalogo_screen.dart';
import '../features/admin/admin_gate_screen.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/pareamento/pareamento_screen.dart';
import '../features/pedido/produto_screen.dart';
import '../features/pedido/carrinho_screen.dart';
import '../features/pedido/peca_tambem_screen.dart';
import '../features/pedido/identificacao_screen.dart';
import '../features/pedido/pagamento_screen.dart';
import '../features/pedido/confirmacao_screen.dart';
import '../features/pedido/venda_nao_concluida_screen.dart';
import '../domain/order/conclusao_venda.dart';

/// Rotas do totem. Sem deep links externos: navegação 100% interna (kiosk).
///
/// Portão de pareamento: enquanto o boot não resolve (`carregando`) NÃO
/// redireciona (não pisca /parear em teste). Sem pareamento (nem JWT de dev) →
/// força /parear; já pareado → tira de /parear.
final router = GoRouter(
  initialLocation: '/descanso',
  refreshListenable: pairingStatus,
  redirect: (context, state) {
    final s = pairingStatus.value;
    if (s == PairStatus.carregando) return null;
    final naPareamento = state.matchedLocation == '/parear';
    if (s == PairStatus.naoPareado && !naPareamento) return '/parear';
    if (s == PairStatus.pareado && naPareamento) return '/descanso';
    return null;
  },
  routes: [
    GoRoute(path: '/parear', builder: (_, __) => const PareamentoScreen()),
    GoRoute(path: '/descanso', builder: (_, __) => const DescansoScreen()),
    GoRoute(path: '/catalogo', builder: (_, __) => const CatalogoScreen()),
    GoRoute(
        path: '/produto/:id',
        builder: (_, s) => ProdutoScreen(produtoId: s.pathParameters['id']!)),
    GoRoute(path: '/carrinho', builder: (_, __) => const CarrinhoScreen()),
    GoRoute(
        path: '/peca-tambem', builder: (_, __) => const PecaTambemScreen()),
    GoRoute(path: '/identificacao', builder: (_, __) => const IdentificacaoScreen()),
    GoRoute(path: '/pagamento', builder: (_, __) => const PagamentoScreen()),
    GoRoute(
        path: '/confirmacao',
        builder: (_, s) => ConfirmacaoScreen(
            senha: s.uri.queryParameters['senha'] ?? '---',
            impresso: s.uri.queryParameters['impresso'] != '0',
            dinheiro: s.uri.queryParameters['dinheiro'] == '1',
            fiscal: s.uri.queryParameters['fiscal'] != '0')),
    // A compra não se concluiu depois do pagamento (nota não emitida, venda recusada,
    // cupom fiscal que não imprimiu): o que houve e o que aconteceu com o dinheiro.
    GoRoute(
        path: '/nao-concluida',
        builder: (_, s) => VendaNaoConcluidaScreen(
            etapa: s.uri.queryParameters['etapa'] ?? '',
            estorno: SituacaoEstorno.values.firstWhere(
                (e) => e.name == s.uri.queryParameters['estorno'],
                orElse: () => SituacaoEstorno.manual),
            motivo: s.uri.queryParameters['motivo'] ?? '',
            senha: s.uri.queryParameters['senha'] ?? '')),
    GoRoute(path: '/admin', builder: (_, __) => const AdminGateScreen()),
    GoRoute(path: '/admin/painel', builder: (_, __) => const AdminPanelScreen()),
  ],
);
