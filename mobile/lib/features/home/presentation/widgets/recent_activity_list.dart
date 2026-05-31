import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/verdict_pill.dart';
import '../../../scan/application/recent_scans_controller.dart';
import '../../../scan/data/scan_models.dart';

/// The home screen's recent-activity section. Watches [recentScansProvider];
/// renders an empty state until the first scan (history is in-memory for now).
class RecentActivityList extends ConsumerWidget {
  const RecentActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scans = ref.watch(recentScansProvider);
    final c = context.qrColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent activity',
          style: TextStyle(
            color: c.brownDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (scans.isEmpty)
          const _EmptyState()
        else
          ...scans.map((record) => _ActivityRow(record: record)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.peachLight.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 36, color: c.brownTint),
          const SizedBox(height: 12),
          Text(
            'No scans yet',
            style: TextStyle(
              color: c.brownMid,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your scanned links will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.brownLight, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.record});
  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.peachLight.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.result.url.isEmpty ? '(empty)' : record.result.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.brownDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                VerdictPill(verdict: record.result.verdict, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
