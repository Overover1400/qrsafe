import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../data/code_models.dart';
import '../data/codes_api.dart';

/// Provides the [CodesApi] data client (built on the shared [dioProvider]).
///
/// Consumed by the codes list/detail controllers and the generator controller
/// (on save). Overridden in tests by overriding [dioProvider] with a mock Dio.
final codesApiProvider = Provider<CodesApi>((ref) {
  return CodesApi(ref.watch(dioProvider));
});

/// All-time analytics for one code, fetched lazily for the detail screen's
/// scan-count line. Static codes (no slug) return zeros; failures surface as the
/// FutureProvider's error state, which the UI treats as "unavailable".
final codeAnalyticsProvider =
    FutureProvider.family<CodeAnalytics, String>((ref, id) {
  return ref.read(codesApiProvider).analytics(id);
});
