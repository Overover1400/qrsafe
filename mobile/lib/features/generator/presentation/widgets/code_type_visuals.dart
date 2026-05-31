import 'package:flutter/material.dart';

import '../../data/code_payload.dart';

/// The icon shown for a [CodeType] in chips, list tiles and detail headers.
IconData codeTypeIcon(CodeType type) => switch (type) {
  CodeType.url => Icons.link_rounded,
  CodeType.wifi => Icons.wifi_rounded,
  CodeType.vcard => Icons.contact_page_rounded,
  CodeType.email => Icons.alternate_email_rounded,
  CodeType.text => Icons.notes_rounded,
};

/// The short human label for a [CodeType].
String codeTypeLabel(CodeType type) => switch (type) {
  CodeType.url => 'URL',
  CodeType.wifi => 'WiFi',
  CodeType.vcard => 'vCard',
  CodeType.email => 'Email',
  CodeType.text => 'Text',
};
