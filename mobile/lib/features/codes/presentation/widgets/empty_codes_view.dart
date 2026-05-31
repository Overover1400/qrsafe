import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';

/// The dashboard's zero-state: a peach illustration and a button that routes to
/// the generator.
class EmptyCodesView extends StatelessWidget {
  const EmptyCodesView({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: c.peachGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'No codes yet',
              style: TextStyle(
                color: c.brownDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first QR code and it’ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.brownLight),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Create your first code',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}
