import 'package:go_router/go_router.dart';
import '../features/descanso/descanso_screen.dart';
import '../features/catalogo/catalogo_screen.dart';
import '../features/admin/admin_gate_screen.dart';

/// Rotas do totem. Sem deep links externos: navegação 100% interna (kiosk).
final router = GoRouter(
  initialLocation: '/descanso',
  routes: [
    GoRoute(path: '/descanso', builder: (_, __) => const DescansoScreen()),
    GoRoute(path: '/catalogo', builder: (_, __) => const CatalogoScreen()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminGateScreen()),
  ],
);
