/// The safety classification of a scanned URL.
///
/// NOTE ON THE BACKEND CONTRACT: `POST /api/v1/scan/check` returns one of
/// `safe | suspicious | malicious` (see backend `internal/safety`). The product
/// design uses a four-state vocabulary, so we map:
///   safe        -> [Verdict.safe]
///   suspicious  -> [Verdict.caution]
///   malicious   -> [Verdict.danger]
///   (anything else / unrecognized) -> [Verdict.unknown]
/// [Verdict.unknown] is also the natural home for "couldn't verify" cases.
enum Verdict {
  safe,
  caution,
  danger,
  unknown;

  /// Maps a backend verdict string to a [Verdict]. Accepts both the backend's
  /// canonical values and the product vocabulary so it's resilient if the API
  /// is ever aligned to the four-state names.
  static Verdict parse(String s) => switch (s.toLowerCase()) {
    'safe' => safe,
    'suspicious' || 'caution' => caution,
    'malicious' || 'danger' => danger,
    _ => unknown,
  };
}

/// One contributing signal behind a verdict. Mirrors the backend's
/// `reasons[].{code, message}`. Rendered as a row in the result sheet's
/// "safety checks" list.
class SafetyReason {
  const SafetyReason({required this.code, required this.message});

  final String code;
  final String message;

  factory SafetyReason.fromJson(Map<String, dynamic> json) => SafetyReason(
    code: (json['code'] as String?) ?? '',
    message: (json['message'] as String?) ?? '',
  );
}

/// The result of a safety check for one URL. Built from the
/// `POST /api/v1/scan/check` response: `{url, verdict, reasons[], cached}`.
class ScanResult {
  const ScanResult({
    required this.url,
    required this.verdict,
    required this.reasons,
    required this.cached,
  });

  /// The URL that was checked (echoed by the server).
  final String url;
  final Verdict verdict;

  /// Signals behind the verdict; empty for a clean `safe` result.
  final List<SafetyReason> reasons;

  /// Whether the server served this verdict from its cache.
  final bool cached;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final rawReasons = (json['reasons'] as List?) ?? const [];
    return ScanResult(
      url: (json['url'] as String?) ?? '',
      verdict: Verdict.parse((json['verdict'] as String?) ?? ''),
      reasons: rawReasons
          .whereType<Map<String, dynamic>>()
          .map(SafetyReason.fromJson)
          .toList(growable: false),
      cached: (json['cached'] as bool?) ?? false,
    );
  }
}

/// A scan plus when it happened — the unit stored in recent activity.
class ScanRecord {
  const ScanRecord({required this.result, required this.scannedAt});

  final ScanResult result;
  final DateTime scannedAt;
}
