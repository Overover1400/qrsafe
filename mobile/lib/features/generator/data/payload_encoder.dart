import 'code_payload.dart';

/// Turns a [CodePayload] into the exact string encoded into a QR code.
///
/// This is the canonical client-side encoder for **static** codes (the QR holds
/// the literal content). Dynamic codes ignore this and encode the backend's
/// `redirect_url` instead — see the generator/detail screens. Kept as pure
/// functions so it's trivially unit-testable and is the single place to extend
/// when adding a new code type.
class PayloadEncoder {
  const PayloadEncoder._();

  static String encode(CodePayload payload) => switch (payload) {
    UrlPayload p => p.normalizedUrl,
    WifiPayload p => _wifi(p),
    VCardPayload p => _vcard(p),
    EmailPayload p => _email(p),
    TextPayload p => p.text,
  };

  // WIFI:T:WPA;S:ssid;P:password;H:false;;  (special chars escaped)
  static String _wifi(WifiPayload p) {
    final s = _wifiEscape(p.ssid);
    final pass = p.auth == WifiAuth.nopass ? '' : _wifiEscape(p.password);
    final h = p.hidden ? 'true' : 'false';
    return 'WIFI:T:${p.auth.wire};S:$s;P:$pass;H:$h;;';
  }

  // vCard 3.0; only non-empty optional fields are emitted, FN is always present.
  static String _vcard(VCardPayload p) {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${_vcardEscape(p.name)}',
      if (p.org.trim().isNotEmpty) 'ORG:${_vcardEscape(p.org)}',
      if (p.phone.trim().isNotEmpty) 'TEL:${_vcardEscape(p.phone)}',
      if (p.email.trim().isNotEmpty) 'EMAIL:${_vcardEscape(p.email)}',
      if (p.url.trim().isNotEmpty) 'URL:${_vcardEscape(p.url)}',
      'END:VCARD',
    ];
    return lines.join('\n');
  }

  // mailto:to?subject=...&body=...  (subject/body percent-encoded)
  static String _email(EmailPayload p) {
    final params = <String>[];
    if (p.subject.trim().isNotEmpty) {
      params.add('subject=${Uri.encodeComponent(p.subject)}');
    }
    if (p.body.trim().isNotEmpty) {
      params.add('body=${Uri.encodeComponent(p.body)}');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return 'mailto:${p.to.trim()}$query';
  }

  // WiFi QR escaping: \ ; , : " are backslash-escaped.
  static String _wifiEscape(String s) =>
      s.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');

  // vCard 3.0 value escaping: \ , ; and newlines.
  static String _vcardEscape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\n', '\\n');
}
