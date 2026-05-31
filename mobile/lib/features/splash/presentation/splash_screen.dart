import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../auth/application/auth_controller.dart';

/// The `/` route. Awaits the auth bootstrap: shows [AppLoader] while it runs and
/// a retry affordance if it fails. The router redirects to `/home` once auth
/// resolves with data, so the success branch here is only momentarily visible.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () => const AppLoader(message: 'Setting things up…'),
      data: (_) => const AppLoader(message: 'Ready'),
      error: (err, _) => _BootstrapError(
        onRetry: () => ref.invalidate(authControllerProvider),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Scaffold(
      backgroundColor: c.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: c.brownLight),
              const SizedBox(height: 16),
              Text(
                "Couldn't start QRSafe",
                style: TextStyle(
                  color: c.brownDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.brownLight),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: c.peach),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
