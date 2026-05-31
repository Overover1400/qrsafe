import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../generator/presentation/widgets/code_type_visuals.dart';
import '../../data/code_models.dart';

/// A single row in the dashboard: a colored type icon, the label + type, and a
/// "Dynamic" badge for dynamic codes. (Per-code scan counts aren't in the list
/// payload, so none is shown here.)
class CodeListTile extends StatelessWidget {
  const CodeListTile({super.key, required this.code, required this.onTap});

  final Code code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.peachLight.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: c.peach.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.peachLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(codeTypeIcon(code.type), color: c.coral),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.brownDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      codeTypeLabel(code.type),
                      style: TextStyle(color: c.brownLight, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (code.isDynamic) const _DynamicBadge(),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: c.brownTint),
            ],
          ),
        ),
      ),
    );
  }
}

class _DynamicBadge extends StatelessWidget {
  const _DynamicBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.safeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Dynamic',
        style: TextStyle(
          color: c.safe,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
