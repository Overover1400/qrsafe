import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The "Dynamic · never expires" toggle card. Enabled only for URL codes;
/// for other types it renders greyed with an explanation (dynamic redirects
/// require a URL destination).
class DynamicToggle extends StatelessWidget {
  const DynamicToggle({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.peachLight.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, color: c.coral),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dynamic · never expires',
                    style: TextStyle(
                      color: c.brownDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? 'Edit where it points later without reprinting.'
                        : 'Only URL codes can be dynamic.',
                    style: TextStyle(color: c.brownLight, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: c.peach,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
