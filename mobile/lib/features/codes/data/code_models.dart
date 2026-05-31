import '../../generator/data/code_payload.dart';
import '../../generator/data/payload_encoder.dart';

/// The dynamic-redirect block attached to a dynamic code. Mirrors the backend's
/// `dynamic` object: `{slug, destination, redirect_url}`. [redirectUrl] is the
/// absolute `/r/{slug}` link the dynamic QR encodes.
class DynamicInfo {
  const DynamicInfo({
    required this.slug,
    required this.destination,
    required this.redirectUrl,
  });

  final String slug;
  final String destination;
  final String redirectUrl;

  factory DynamicInfo.fromJson(Map<String, dynamic> json) => DynamicInfo(
    slug: (json['slug'] as String?) ?? '',
    destination: (json['destination'] as String?) ?? '',
    redirectUrl: (json['redirect_url'] as String?) ?? '',
  );

  DynamicInfo copyWith({String? destination}) => DynamicInfo(
    slug: slug,
    destination: destination ?? this.destination,
    redirectUrl: redirectUrl,
  );
}

/// One saved code. Built from the backend envelope
/// `{code:{...}, dynamic?:{...}}`. [payload] is the raw stored JSON object;
/// reconstruct a typed [CodePayload] with [typedPayload] to re-render its QR.
class Code {
  const Code({
    required this.id,
    required this.type,
    required this.payload,
    required this.label,
    required this.isDynamic,
    required this.createdAt,
    required this.updatedAt,
    this.dynamicInfo,
  });

  final String id;
  final CodeType type;
  final Map<String, dynamic> payload;
  final String? label;
  final bool isDynamic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DynamicInfo? dynamicInfo;

  /// The typed payload, reconstructed from the stored JSON for this code's type.
  CodePayload get typedPayload => CodePayload.fromJson(type, payload);

  /// What the code's QR should encode: a dynamic code encodes its redirect URL;
  /// a static code encodes the literal payload content.
  String get qrContent {
    if (isDynamic && dynamicInfo != null) return dynamicInfo!.redirectUrl;
    return PayloadEncoder.encode(typedPayload);
  }

  /// A human label, falling back to the type name when unlabeled.
  String get displayLabel =>
      (label != null && label!.trim().isNotEmpty) ? label!.trim() : type.wire;

  factory Code.fromEnvelope(Map<String, dynamic> json) {
    final code = (json['code'] as Map<String, dynamic>?) ?? const {};
    final dyn = json['dynamic'] as Map<String, dynamic>?;
    return Code(
      id: (code['id'] as String?) ?? '',
      type: CodeType.parse((code['type'] as String?) ?? 'text'),
      payload: (code['payload'] as Map<String, dynamic>?) ?? const {},
      label: code['label'] as String?,
      isDynamic: (code['is_dynamic'] as bool?) ?? false,
      createdAt: DateTime.tryParse((code['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((code['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dynamicInfo: dyn == null ? null : DynamicInfo.fromJson(dyn),
    );
  }

  Code copyWith({String? label, DynamicInfo? dynamicInfo}) => Code(
    id: id,
    type: type,
    payload: payload,
    label: label ?? this.label,
    isDynamic: isDynamic,
    createdAt: createdAt,
    updatedAt: updatedAt,
    dynamicInfo: dynamicInfo ?? this.dynamicInfo,
  );
}

/// A page of the user's codes plus the cursor for the next page.
/// [hasMore] is true when the backend returned a non-null `next_cursor`.
class PaginatedCodes {
  const PaginatedCodes({required this.codes, this.nextCursor});

  final List<Code> codes;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory PaginatedCodes.fromJson(Map<String, dynamic> json) {
    final raw = (json['codes'] as List?) ?? const [];
    return PaginatedCodes(
      codes: raw
          .whereType<Map<String, dynamic>>()
          .map(Code.fromEnvelope)
          .toList(growable: false),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  PaginatedCodes copyWith({List<Code>? codes, String? nextCursor}) =>
      PaginatedCodes(codes: codes ?? this.codes, nextCursor: nextCursor);
}

/// All-time scan analytics for one code. Built from the backend
/// `{analytics:{...}}` envelope. The dashboard has no account-wide or weekly
/// rollup available, so it uses [totalScans] where a per-code number is shown.
class CodeAnalytics {
  const CodeAnalytics({
    required this.codeId,
    required this.totalScans,
    required this.uniqueVisitors,
    required this.daily,
  });

  final String codeId;
  final int totalScans;
  final int uniqueVisitors;
  final List<DayCount> daily;

  factory CodeAnalytics.fromEnvelope(Map<String, dynamic> json) {
    final a = (json['analytics'] as Map<String, dynamic>?) ?? const {};
    final daily = (a['daily'] as List?) ?? const [];
    return CodeAnalytics(
      codeId: (a['code_id'] as String?) ?? '',
      totalScans: (a['total_scans'] as num?)?.toInt() ?? 0,
      uniqueVisitors: (a['unique_visitors'] as num?)?.toInt() ?? 0,
      daily: daily
          .whereType<Map<String, dynamic>>()
          .map(DayCount.fromJson)
          .toList(growable: false),
    );
  }
}

/// A single day's scan count (`date` is `YYYY-MM-DD`, UTC).
class DayCount {
  const DayCount({required this.date, required this.count});
  final String date;
  final int count;

  factory DayCount.fromJson(Map<String, dynamic> json) => DayCount(
    date: (json['date'] as String?) ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}
