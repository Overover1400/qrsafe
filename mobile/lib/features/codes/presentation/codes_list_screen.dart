import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../application/codes_list_controller.dart';
import '../data/code_models.dart';
import 'widgets/code_list_tile.dart';
import 'widgets/empty_codes_view.dart';

/// The dashboard: a peach stat card, an "Active codes · N" header, and the
/// scrollable list of the user's codes with pull-to-refresh and infinite scroll.
class CodesListScreen extends ConsumerWidget {
  const CodesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    final state = ref.watch(codesListControllerProvider);

    return Scaffold(
      backgroundColor: c.cream,
      appBar: AppBar(
        title: const Text('My codes'),
        actions: [
          IconButton(
            tooltip: 'New code',
            icon: Icon(Icons.add_rounded, color: c.coral),
            onPressed: () => context.push('/create'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoader(),
        error: (err, _) => _ErrorView(
          message: err is ApiException ? err.message : 'Something went wrong.',
          onRetry: () => ref.read(codesListControllerProvider.notifier).refresh(),
        ),
        data: (page) => RefreshIndicator(
          color: c.peach,
          onRefresh: () =>
              ref.read(codesListControllerProvider.notifier).refresh(),
          child: page.codes.isEmpty
              ? ListView(
                  // ListView so pull-to-refresh works over the empty state.
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: EmptyCodesView(
                        onCreate: () => context.push('/create'),
                      ),
                    ),
                  ],
                )
              : _CodesList(page: page),
        ),
      ),
    );
  }
}

class _CodesList extends ConsumerWidget {
  const _CodesList({required this.page});
  final PaginatedCodes page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 && page.hasMore) {
          ref.read(codesListControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: page.codes.length + 2, // stat card + header + tiles
        separatorBuilder: (context, i) =>
            SizedBox(height: i == 0 ? 20 : 10),
        itemBuilder: (context, i) {
          if (i == 0) return const _StatCard();
          if (i == 1) return _ActiveHeader(count: page.codes.length);
          final code = page.codes[i - 2];
          return CodeListTile(
            code: code,
            onTap: () => context.push('/codes/${code.id}'),
          );
        },
      ),
    );
  }
}

/// Peach gradient stat card. The backend exposes only per-code, all-time
/// analytics (no account-wide weekly rollup), so the weekly figure shows "—".
class _StatCard extends StatelessWidget {
  const _StatCard();

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.peachGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scans this week',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            '—',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly totals are coming soon.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Row(
      children: [
        Text(
          'Active codes · $count',
          style: TextStyle(
            color: c.brownDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.safeBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Never expire',
            style: TextStyle(color: c.safe, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: c.brownLight),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: c.peach),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
