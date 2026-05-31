import 'package:flutter/material.dart';

import '../../features/scan/data/scan_models.dart';
import '../theme/app_theme.dart';

/// Resolved visual treatment for a [Verdict]: foreground/background colors,
/// the short pill label, and a matching icon. Centralized here so the pill and
/// the result sheet stay visually consistent.
class VerdictStyle {
  const VerdictStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData icon;

  /// Maps a [Verdict] to its style using the theme's [QRSafeColors].
  factory VerdictStyle.of(BuildContext context, Verdict verdict) {
    final c = context.qrColors;
    return switch (verdict) {
      Verdict.safe => VerdictStyle(
        label: 'Verified safe',
        foreground: c.safe,
        background: c.safeBg,
        icon: Icons.verified_rounded,
      ),
      Verdict.caution => VerdictStyle(
        label: 'Use caution',
        foreground: c.caution,
        background: c.cautionBg,
        icon: Icons.warning_amber_rounded,
      ),
      Verdict.danger => VerdictStyle(
        label: 'Blocked — suspicious link',
        foreground: c.danger,
        background: c.dangerBg,
        icon: Icons.block_rounded,
      ),
      Verdict.unknown => VerdictStyle(
        label: "Couldn't verify",
        foreground: c.unknown,
        background: c.unknownBg,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}

/// A rounded pill showing a verdict's icon + label in its themed colors.
/// Used in the scan result sheet header and recent-activity rows.
class VerdictPill extends StatelessWidget {
  const VerdictPill({super.key, required this.verdict, this.compact = false});

  final Verdict verdict;

  /// When true, renders a tighter pill (used in dense list rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(context, verdict);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 14 : 18, color: style.foreground),
          SizedBox(width: compact ? 5 : 8),
          Text(
            style.label,
            style: TextStyle(
              color: style.foreground,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
