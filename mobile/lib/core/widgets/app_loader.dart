import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen branded loading state: the QRSafe wordmark over a peach spinner
/// on the cream background. Shown while auth bootstraps.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});

  /// Optional status line under the spinner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Scaffold(
      backgroundColor: c.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: c.peach, size: 56),
            const SizedBox(height: 12),
            Text(
              'QRSafe',
              style: TextStyle(
                color: c.brownDark,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 28),
            CircularProgressIndicator(color: c.peach),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: TextStyle(color: c.brownLight)),
            ],
          ],
        ),
      ),
    );
  }
}
