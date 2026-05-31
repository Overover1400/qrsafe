import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The peach-gradient CTA used across the app (e.g. the home hero, sheet
/// actions). Pass [onPressed] null to render a disabled (dimmed) state.
///
/// For non-gradient variants (e.g. the amber "Open anyway" or a solid brown
/// button), use [PrimaryButton.solid] with an explicit [color] — a non-null
/// [color] switches off the gradient.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.subtitle,
  }) : color = null;

  /// A solid-color variant (no gradient) — used for brown "Open link" and amber
  /// "Open anyway" actions.
  const PrimaryButton.solid({
    super.key,
    required this.label,
    required this.onPressed,
    required Color this.color,
    this.icon,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Optional secondary line under the label (e.g. a caution note).
  final String? subtitle;

  /// Solid background color; when null the peach gradient is used.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final gradient = color == null ? context.qrColors.peachGradient : null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              color: color,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
