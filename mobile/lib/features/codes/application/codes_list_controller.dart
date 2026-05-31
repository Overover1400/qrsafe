import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/code_models.dart';
import '../data/codes_api.dart';
import 'codes_providers.dart';

/// The dashboard's paginated list of the user's codes.
///
/// `build()` loads the first page. The list screen watches this; it calls
/// [refresh] (pull-to-refresh) and [loadMore] (infinite scroll). The generator
/// calls [optimisticallyAddCode] after a save and the detail controller calls
/// [optimisticallyRemoveCode]/[replaceCode] after delete/edit, so the dashboard
/// updates without a refetch.
final codesListControllerProvider =
    AsyncNotifierProvider<CodesListController, PaginatedCodes>(
      CodesListController.new,
    );

class CodesListController extends AsyncNotifier<PaginatedCodes> {
  CodesApi get _api => ref.read(codesApiProvider);

  /// Guards against overlapping [loadMore] calls from rapid scrolling.
  bool _loadingMore = false;

  @override
  Future<PaginatedCodes> build() => _api.list();

  /// Reloads the first page (pull-to-refresh). Keeps the current data visible
  /// while loading by guarding into a fresh AsyncValue.
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _api.list());
  }

  /// Fetches the next page (if any) and appends it. No-op when there's no
  /// next cursor or a load is already in flight.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _api.list(cursor: current.nextCursor);
      state = AsyncData(
        PaginatedCodes(
          codes: [...current.codes, ...next.codes],
          nextCursor: next.nextCursor,
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }

  /// Inserts [code] at the top (newest first) right after a save.
  void optimisticallyAddCode(Code code) {
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData(PaginatedCodes(codes: [code]));
      return;
    }
    state = AsyncData(
      PaginatedCodes(
        codes: [code, ...current.codes],
        nextCursor: current.nextCursor,
      ),
    );
  }

  /// Removes the code with [id] (optimistic delete).
  void optimisticallyRemoveCode(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      PaginatedCodes(
        codes: current.codes.where((c) => c.id != id).toList(growable: false),
        nextCursor: current.nextCursor,
      ),
    );
  }

  /// Replaces an existing code in place (after a label/destination edit).
  void replaceCode(Code code) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      PaginatedCodes(
        codes: [
          for (final c in current.codes) c.id == code.id ? code : c,
        ],
        nextCursor: current.nextCursor,
      ),
    );
  }
}
