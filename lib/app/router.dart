import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_state.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/calls/active_call_screen.dart';
import 'home_shell.dart';
import 'providers.dart';

class Routes {
  const Routes._();

  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const call = '/call';
}

/// Routing is derived from state rather than pushed imperatively: auth state
/// decides login vs. home, and an active call always wins. That keeps the app
/// consistent when a call arrives while the user is somewhere else entirely —
/// including a cold start from a push notification.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, routerState) {
      final auth = ref.read(authStateProvider).value ?? const AuthState();
      final hasCall = ref.read(activeCallProvider).hasCall;

      if (!auth.isResolved) return Routes.splash;
      if (!auth.isAuthenticated) return Routes.login;
      if (hasCall) return Routes.call;
      final location = routerState.matchedLocation;
      if (location == Routes.splash ||
          location == Routes.login ||
          location == Routes.call) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeShell()),
      GoRoute(path: Routes.call, builder: (_, _) => const ActiveCallScreen()),
    ],
  );
});

/// Bridges the two providers that affect routing to GoRouter's [Listenable]
/// refresh hook.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(activeCallProvider, (_, _) => notifyListeners());
  }
}
