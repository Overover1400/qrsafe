import 'package:flutter/material.dart';

import '../../data/code_payload.dart';
import 'email_form.dart';
import 'text_form.dart';
import 'url_form.dart';
import 'vcard_form.dart';
import 'wifi_form.dart';

/// Dispatches to the type-specific subform for [payload] and bubbles edits up
/// via [onChanged]. Adding a new code type means adding a case here (and a chip
/// + an encoder branch).
class PayloadForm extends StatelessWidget {
  const PayloadForm({super.key, required this.payload, required this.onChanged});

  final CodePayload payload;
  final ValueChanged<CodePayload> onChanged;

  @override
  Widget build(BuildContext context) {
    // Keyed by type so switching types rebuilds fields with fresh initialValues.
    return KeyedSubtree(
      key: ValueKey(payload.type),
      child: switch (payload) {
        UrlPayload p => UrlForm(payload: p, onChanged: onChanged),
        WifiPayload p => WifiForm(payload: p, onChanged: onChanged),
        VCardPayload p => VCardForm(payload: p, onChanged: onChanged),
        EmailPayload p => EmailForm(payload: p, onChanged: onChanged),
        TextPayload p => TextForm(payload: p, onChanged: onChanged),
      },
    );
  }
}
