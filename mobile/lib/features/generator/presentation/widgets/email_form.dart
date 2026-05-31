import 'package:flutter/material.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../data/code_payload.dart';

/// Recipient (required) plus optional subject and body.
class EmailForm extends StatelessWidget {
  const EmailForm({super.key, required this.payload, required this.onChanged});

  final EmailPayload payload;
  final ValueChanged<EmailPayload> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          label: 'To',
          hint: 'name@example.com',
          initialValue: payload.to,
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => onChanged(payload.copyWith(to: v)),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Subject (optional)',
          initialValue: payload.subject,
          onChanged: (v) => onChanged(payload.copyWith(subject: v)),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Body (optional)',
          initialValue: payload.body,
          maxLines: 4,
          onChanged: (v) => onChanged(payload.copyWith(body: v)),
        ),
      ],
    );
  }
}
