import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../data/scan_api.dart';
import '../data/scan_models.dart';

/// Provides the [ScanApi] data client. Consumed only by [ScanController].
final scanApiProvider = Provider<ScanApi>((ref) {
  return ScanApi(ref.watch(dioProvider));
});

/// Drives a single safety-check request.
///
/// The scanner screen calls [check] when a QR is detected, then shows the
/// result sheet which watches this provider's [state]: loading → spinner,
/// data → verdict, error → error message. State is null until the first check.
/// Consumed by: `ScannerScreen` and `ScanResultSheet`.
final scanControllerProvider =
    AsyncNotifierProvider<ScanController, ScanResult?>(ScanController.new);

class ScanController extends AsyncNotifier<ScanResult?> {
  @override
  Future<ScanResult?> build() async => null;

  /// Runs the safety check for [rawValue] (the decoded QR contents). Drives
  /// [state] through loading → data/error and returns the result (or null on
  /// failure) so callers that prefer a direct return can use it.
  Future<ScanResult?> check(String rawValue) async {
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(
      () => ref.read(scanApiProvider).check(rawValue.trim()),
    );
    state = next;
    return next.valueOrNull;
  }

  /// Resets to the idle (no-result) state — called when the result sheet is
  /// dismissed so the scanner is ready for the next code.
  void reset() => state = const AsyncValue.data(null);
}
