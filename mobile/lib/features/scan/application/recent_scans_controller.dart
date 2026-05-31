import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scan_models.dart';

/// In-memory list of recent scans, newest first.
///
/// PHASE NOTE: this is intentionally not persisted yet — it resets on app
/// restart. Durable history (local DB / server sync) is a later brief. Consumed
/// by: the home screen's recent-activity list; written by the result sheet
/// after a scan is dismissed.
final recentScansProvider =
    NotifierProvider<RecentScansController, List<ScanRecord>>(
      RecentScansController.new,
    );

class RecentScansController extends Notifier<List<ScanRecord>> {
  /// Cap the in-memory list so it can't grow unbounded in a long session.
  static const _maxEntries = 50;

  @override
  List<ScanRecord> build() => const [];

  /// Prepends [record] (newest first), trimming to [_maxEntries].
  void add(ScanRecord record) {
    state = [record, ...state].take(_maxEntries).toList(growable: false);
  }

  /// Clears all recorded scans (used by "Clear local data").
  void clear() => state = const [];
}
