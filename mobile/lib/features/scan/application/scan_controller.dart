import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../data/scan_api.dart';
import '../data/scan_models.dart';

/// Provides the [ScanApi] data client. Consumed only by [ScanController].
final scanApiProvider = Provider<ScanApi>((ref) {
  return ScanApi(ref.watch(dioProvider));
});

/// True when [raw] is something a browser could open, which is the only kind
/// of value the safety check understands.
///
/// Deliberately narrow: an `http`/`https` URL, or a bare host like
/// `example.com/x` that a user would expect to open. A product barcode
/// (`4006381333931`), a phone number or a line of text is not a link and must
/// not be sent to the server, which would call it malicious for having no
/// scheme.
bool looksLikeWebLink(String raw) {
  final v = raw.trim();
  if (v.isEmpty || v.contains(' ')) return false;
  final lower = v.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
  // Anything else carrying a scheme or an address is not a web link:
  // mailto:, tel:, geo:, bitcoin:, the WIFI: payload, a bare email address.
  // Without this, `mailto:a@b.com` ends in `.com` and slips through as a host.
  if (lower.contains(':') || lower.contains('@')) return false;
  // A bare host: at least one dot and a letter-only last label of 2+ chars.
  final host = lower.split('/').first.split('?').first;
  final labels = host.split('.');
  if (labels.length < 2) return false;
  final tld = labels.last;
  return tld.length >= 2 && RegExp(r'^[a-z]+$').hasMatch(tld);
}

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
    final trimmed = rawValue.trim();
    if (!looksLikeWebLink(trimmed)) {
      final plain = ScanResult.plain(trimmed);
      state = AsyncValue.data(plain);
      return plain;
    }
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
