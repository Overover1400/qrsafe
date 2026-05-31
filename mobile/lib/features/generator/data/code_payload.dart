/// The five QR code types the generator supports (the backend also accepts
/// `sms`, but the mobile UI ships these five for v1).
///
/// [wire] is the string the backend stores in `code.type`; [parse] maps a wire
/// value back to an enum (defaulting to [text] for anything unrecognized so the
/// dashboard never crashes on an unknown type).
enum CodeType {
  url('url'),
  wifi('wifi'),
  vcard('vcard'),
  email('email'),
  text('text');

  const CodeType(this.wire);

  /// The value stored in / sent to the backend `type` field.
  final String wire;

  static CodeType parse(String s) {
    for (final t in CodeType.values) {
      if (t.wire == s) return t;
    }
    return CodeType.text;
  }

  /// Only URL codes may be dynamic (server constraint).
  bool get supportsDynamic => this == CodeType.url;
}

/// WiFi authentication scheme for [WifiPayload].
enum WifiAuth {
  wpa('WPA'),
  wep('WEP'),
  nopass('nopass');

  const WifiAuth(this.wire);
  final String wire;

  static WifiAuth parse(String? s) {
    for (final a in WifiAuth.values) {
      if (a.wire == s) return a;
    }
    return WifiAuth.wpa;
  }
}

/// The structured contents of a code, one variant per [CodeType].
///
/// Two responsibilities:
/// - [toJson] is the JSON object stored on the backend `payload` field. The
///   backend treats it opaquely except that a dynamic url code needs `url`.
/// - The variant's fields are what `payload_encoder.dart` turns into the actual
///   string encoded into the QR. Reconstruct one from stored data with
///   [CodePayload.fromJson] (used by the detail screen to re-render).
sealed class CodePayload {
  const CodePayload();

  CodeType get type;

  /// JSON object persisted on the backend (and re-hydrated by [fromJson]).
  Map<String, dynamic> toJson();

  /// Whether the required fields are present (gates the Save button).
  bool get isValid;

  /// Rebuilds a payload from a stored backend `payload` map for [type].
  factory CodePayload.fromJson(CodeType type, Map<String, dynamic> json) {
    String s(String k) => (json[k] as String?)?.trim() ?? '';
    return switch (type) {
      CodeType.url => UrlPayload(url: s('url')),
      CodeType.wifi => WifiPayload(
        ssid: s('ssid'),
        password: s('password'),
        auth: WifiAuth.parse(json['auth'] as String?),
        hidden: (json['hidden'] as bool?) ?? false,
      ),
      CodeType.vcard => VCardPayload(
        name: s('name'),
        org: s('org'),
        phone: s('phone'),
        email: s('email'),
        url: s('url'),
      ),
      CodeType.email => EmailPayload(
        to: s('to'),
        subject: s('subject'),
        body: s('body'),
      ),
      CodeType.text => TextPayload(text: (json['text'] as String?) ?? ''),
    };
  }

  /// An empty payload of [type] (initial form state).
  factory CodePayload.empty(CodeType type) {
    return switch (type) {
      CodeType.url => const UrlPayload(url: ''),
      CodeType.wifi => const WifiPayload(ssid: '', password: ''),
      CodeType.vcard => const VCardPayload(name: ''),
      CodeType.email => const EmailPayload(to: ''),
      CodeType.text => const TextPayload(text: ''),
    };
  }
}

class UrlPayload extends CodePayload {
  const UrlPayload({required this.url});
  final String url;

  @override
  CodeType get type => CodeType.url;

  @override
  bool get isValid => url.trim().isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {'url': normalizedUrl};

  /// The url with an `https://` scheme prepended when the user omitted one.
  String get normalizedUrl => _normalizeUrl(url);

  UrlPayload copyWith({String? url}) => UrlPayload(url: url ?? this.url);
}

class WifiPayload extends CodePayload {
  const WifiPayload({
    required this.ssid,
    this.password = '',
    this.auth = WifiAuth.wpa,
    this.hidden = false,
  });

  final String ssid;
  final String password;
  final WifiAuth auth;
  final bool hidden;

  @override
  CodeType get type => CodeType.wifi;

  @override
  bool get isValid => ssid.trim().isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'password': auth == WifiAuth.nopass ? '' : password,
    'auth': auth.wire,
    'hidden': hidden,
  };

  WifiPayload copyWith({
    String? ssid,
    String? password,
    WifiAuth? auth,
    bool? hidden,
  }) => WifiPayload(
    ssid: ssid ?? this.ssid,
    password: password ?? this.password,
    auth: auth ?? this.auth,
    hidden: hidden ?? this.hidden,
  );
}

class VCardPayload extends CodePayload {
  const VCardPayload({
    required this.name,
    this.org = '',
    this.phone = '',
    this.email = '',
    this.url = '',
  });

  final String name;
  final String org;
  final String phone;
  final String email;
  final String url;

  @override
  CodeType get type => CodeType.vcard;

  @override
  bool get isValid => name.trim().isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'org': org,
    'phone': phone,
    'email': email,
    'url': url,
  };

  VCardPayload copyWith({
    String? name,
    String? org,
    String? phone,
    String? email,
    String? url,
  }) => VCardPayload(
    name: name ?? this.name,
    org: org ?? this.org,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    url: url ?? this.url,
  );
}

class EmailPayload extends CodePayload {
  const EmailPayload({required this.to, this.subject = '', this.body = ''});

  final String to;
  final String subject;
  final String body;

  @override
  CodeType get type => CodeType.email;

  @override
  bool get isValid => to.trim().isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'to': to,
    'subject': subject,
    'body': body,
  };

  EmailPayload copyWith({String? to, String? subject, String? body}) =>
      EmailPayload(
        to: to ?? this.to,
        subject: subject ?? this.subject,
        body: body ?? this.body,
      );
}

class TextPayload extends CodePayload {
  const TextPayload({required this.text});
  final String text;

  /// Max characters allowed in a text code (form enforces this too).
  static const maxLength = 2000;

  @override
  CodeType get type => CodeType.text;

  @override
  bool get isValid => text.trim().isNotEmpty && text.length <= maxLength;

  @override
  Map<String, dynamic> toJson() => {'text': text};

  TextPayload copyWith({String? text}) => TextPayload(text: text ?? this.text);
}

/// Prepends `https://` when [raw] has no URI scheme (e.g. `example.com`).
String _normalizeUrl(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').hasMatch(t)) return t;
  return 'https://$t';
}
