import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../scan/application/recent_scans_controller.dart';

/// Settings: shows the API URL the app was built against, the app version, and a
/// "Clear local data" action that wipes the guest token (re-bootstrapping a new
/// guest) and the in-memory recent scans.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
      backgroundColor: c.cream,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
            label: 'Clear local data',
            color: c.coral,
            icon: Icons.delete_outline_rounded,
            onPressed: auth.isLoading
                ? null
                : () => _clearLocalData(context, ref),
          ),
          const SizedBox(height: 12),
          Text(
            'Removes your guest session token and clears recent scans. A fresh '
            'guest account is created automatically.',
            style: TextStyle(color: c.brownLight, fontSize: 13),
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
          color: context.qrColors.peachLight.withValues(alpha: 0.6),
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
          style: TextStyle(color: c.brownLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: c.brownDark, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
