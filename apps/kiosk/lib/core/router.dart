import 'package:go_router/go_router.dart';
import '../features/descanso/descanso_screen.dart';
import '../features/catalogo/catalogo_screen.dart';
import '../features/admin/admin_gate_screen.dart';
import '../features/pedido/produto_screen.dart';
import '../features/pedido/carrinho_screen.dart';
import '../features/pedido/identificacao_screen.dart';
import '../features/pedido/pagamento_screen.dart';
import '../features/pedido/confirmacao_screen.dart';

/// Rotas do totem. Sem deep links externos: navegação 100% interna (kiosk).
final router = GoRouter(
  initialLocation: '/descanso',
  routes: [
    GoRoute(path: '/descanso', builder: (_, __) => const DescansoScreen()),
    GoRoute(path: '/catalogo', builder: (_, __) => const CatalogoScreen()),
    GoRoute(
        path: '/produto/:id',
        builder: (_, s) => ProdutoScreen(produtoId: s.pathParameters['id']!)),
    GoRoute(path: '/carrinho', builder: (_, __) => const CarrinhoScreen()),
    GoRoute(path: '/identificacao', builder: (_, __) => const IdentificacaoScreen()),
    GoRoute(path: '/pagamento', builder: (_, __) => const PagamentoScreen()),
    GoRoute(
        path: '/confirmacao',
        builder: (_, s) =>
            ConfirmacaoScreen(senha: s.uri.queryParameters['senha'] ?? '---')),
    GoRoute(path: '/admin', builder: (_, __) => const AdminGateScreen()),
  ],
);
