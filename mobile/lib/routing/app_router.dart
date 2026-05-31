import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/scan/presentation/scanner_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

/// Provides the app's [GoRouter].
///
/// The redirect gates the whole app on the auth bootstrap: until
/// [authControllerProvider] resolves with data, every location funnels back to
/// the splash (`/`); once a user exists, `/` hands off to `/home`. A
/// [ValueNotifier] bumped on every auth state change drives `refreshListenable`
/// so the redirect re-evaluates when bootstrap completes. Consumed by `app.dart`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final atSplash = state.matchedLocation == '/';
      // While bootstrapping or on error, stay on (or return to) the splash.
      if (auth.isLoading || auth.hasError) {
        return atSplash ? null : '/';
      }
      // Authenticated: leave the splash for home; otherwise stay put.
      return atSplash ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/scan', builder: (_, _) => const ScannerScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
