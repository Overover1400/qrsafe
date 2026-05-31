import 'package:flutter/material.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../data/code_payload.dart';

/// Multiline free text, capped at [TextPayload.maxLength] characters.
class TextForm extends StatelessWidget {
  const TextForm({super.key, required this.payload, required this.onChanged});

  final TextPayload payload;
  final ValueChanged<TextPayload> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Text',
      initialValue: payload.text,
      maxLines: 5,
      maxLength: TextPayload.maxLength,
      onChanged: (v) => onChanged(payload.copyWith(text: v)),
    );
  }
}
