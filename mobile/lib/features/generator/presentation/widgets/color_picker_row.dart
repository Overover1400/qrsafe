import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/generator_controller.dart';

/// A row of curated foreground swatches. Selecting one sets the QR foreground
/// color (a client-side render choice only — not sent to the backend in v1).
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Row(
      children: [
        for (final value in generatorSwatches) ...[
          GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(
                  color: value == selected ? c.brownDark : Colors.transparent,
                  width: 3,
                ),
              ),
              child: value == selected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}
