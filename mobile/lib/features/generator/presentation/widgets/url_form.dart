import 'package:flutter/material.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../data/code_payload.dart';

/// Single URL field. `https://` is auto-prepended at encode time when omitted.
class UrlForm extends StatelessWidget {
  const UrlForm({super.key, required this.payload, required this.onChanged});

  final UrlPayload payload;
  final ValueChanged<UrlPayload> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'URL',
      hint: 'example.com',
      initialValue: payload.url,
      keyboardType: TextInputType.url,
      onChanged: (v) => onChanged(payload.copyWith(url: v)),
    );
  }
}
