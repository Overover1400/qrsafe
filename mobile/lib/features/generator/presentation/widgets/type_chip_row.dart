import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/code_payload.dart';
import 'code_type_visuals.dart';

/// Horizontal, scrollable selector for the five code types. Calls [onSelected]
/// when a chip is tapped; the active chip uses the peach gradient.
class TypeChipRow extends StatelessWidget {
  const TypeChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CodeType selected;
  final ValueChanged<CodeType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CodeType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = CodeType.values[i];
          return _Chip(
            type: type,
            active: type == selected,
            onTap: () => onSelected(type),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.type, required this.active, required this.onTap});

  final CodeType type;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: active ? c.peachGradient : null,
            color: active ? null : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : c.peachLight.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  codeTypeIcon(type),
                  size: 18,
                  color: active ? Colors.white : c.brownMid,
                ),
                const SizedBox(width: 6),
                Text(
                  codeTypeLabel(type),
                  style: TextStyle(
                    color: active ? Colors.white : c.brownMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
