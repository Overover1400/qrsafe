import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../scan/application/recent_scans_controller.dart';

/// Settings: shows the API URL the app was built against, the app version, and a
/// "Clear local data" action that wipes the guest token (re-bootstrapping a new
/// guest) and the in-memory recent scans.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Opens Google in the browser. The token comes back to the app over the
  /// `qrsafe://auth` deep link, so there is nothing to await here beyond the
  /// browser opening at all.
  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened =
          await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't open the browser.")),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Signed out.')),
      );
    }
  }

  Future<void> _clearLocalData(BuildContext context, WidgetRef ref) async {
    ref.read(recentScansProvider.notifier).clear();
    await ref.read(authControllerProvider.notifier).resetGuest();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data cleared. New guest created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Account')),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AccountCard(
            onSignIn: () => _signInWithGoogle(context, ref),
            onSignOut: () => _signOut(context, ref),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            children: [
              _InfoRow(label: 'API URL', value: Env.apiBaseUrl),
              const Divider(height: 24),
              _InfoRow(label: 'App version', value: Env.appVersion),
              const Divider(height: 24),
              _InfoRow(
                label: 'Session',
                value: auth.isLoading
                    ? 'Refreshing…'
                    : auth.hasError
                        ? 'Error'
                        : 'Guest (${_shortId(auth.valueOrNull?.id)})',
              ),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton.solid(
            label: 'My saved codes',
            color: c.inkDark,
            icon: Icons.qr_code_2_rounded,
            onPressed: () => context.push('/codes'),
          ),
          const SizedBox(height: 12),
          PrimaryButton.solid(
            label: 'Clear local data',
            color: c.accent,
            icon: Icons.delete_outline_rounded,
            onPressed: auth.isLoading
                ? null
                : () => _clearLocalData(context, ref),
          ),
          const SizedBox(height: 12),
          Text(
            'Removes your guest session token and clears recent scans. A fresh '
            'guest account is created automatically.',
            style: TextStyle(color: c.inkLight, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _shortId(String? id) {
    if (id == null || id.isEmpty) return 'unknown';
    return id.length <= 8 ? id : id.substring(0, 8);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.qrColors.tealLight.withValues(alpha: 0.6),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: c.inkLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: c.inkDark, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}


/// Who is signed in, and the one button that changes it.
///
/// Signing in matters beyond convenience: a guest session lives in this
/// install only, so codes made before signing in are lost with the app.
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.onSignIn, required this.onSignOut});

  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull;
    final signedIn = user != null && !user.isGuest;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.tealLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                signedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                color: signedIn ? c.safe : c.inkTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  signedIn
                      ? (user.email ?? 'Signed in')
                      : 'Not signed in',
                  style: TextStyle(
                    color: c.inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            signedIn
                ? 'Your codes are saved to this account.'
                : 'Sign in to keep your codes if you change phone or reinstall.',
            style: TextStyle(color: c.inkLight, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (signedIn)
            TextButton.icon(
              onPressed: auth.isLoading ? null : onSignOut,
              icon: Icon(Icons.logout_rounded, color: c.inkMid),
              label: Text(
                'Sign out',
                style: TextStyle(color: c.inkMid, fontWeight: FontWeight.w600),
              ),
            )
          else
            PrimaryButton.solid(
              label: 'Continue with Google',
              color: c.teal,
              icon: Icons.account_circle_rounded,
              onPressed: auth.isLoading ? null : onSignIn,
            ),
        ],
      ),
    );
  }
}
