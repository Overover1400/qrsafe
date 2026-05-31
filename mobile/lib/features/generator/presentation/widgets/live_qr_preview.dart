import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/qr_view.dart';

/// The centered white QR card with a soft peach shadow, plus the green
/// "No watermark · Yours forever" reassurance pill below it.
class LiveQrPreview extends StatelessWidget {
  const LiveQrPreview({super.key, required this.data, required this.color});

  final String data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: c.peach.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: QrView(data: data, color: color, size: 200),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: c.safeBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 16, color: c.safe),
              const SizedBox(width: 6),
              Text(
                'No watermark · Yours forever',
                style: TextStyle(color: c.safe, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
