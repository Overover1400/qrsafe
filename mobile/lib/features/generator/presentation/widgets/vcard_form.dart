import 'package:flutter/material.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../data/code_payload.dart';

/// Contact fields: name (required) plus optional org, phone, email, website.
class VCardForm extends StatelessWidget {
  const VCardForm({super.key, required this.payload, required this.onChanged});

  final VCardPayload payload;
  final ValueChanged<VCardPayload> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          label: 'Name',
          initialValue: payload.name,
          onChanged: (v) => onChanged(payload.copyWith(name: v)),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Organization (optional)',
          initialValue: payload.org,
          onChanged: (v) => onChanged(payload.copyWith(org: v)),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Phone (optional)',
          initialValue: payload.phone,
          keyboardType: TextInputType.phone,
          onChanged: (v) => onChanged(payload.copyWith(phone: v)),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Email (optional)',
          initialValue: payload.email,
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => onChanged(payload.copyWith(email: v)),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Website (optional)',
          initialValue: payload.url,
          keyboardType: TextInputType.url,
          onChanged: (v) => onChanged(payload.copyWith(url: v)),
        ),
      ],
    );
  }
}
