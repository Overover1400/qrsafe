import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/code_payload.dart';

/// SSID, password, auth-type dropdown and a hidden-network toggle.
class WifiForm extends StatelessWidget {
  const WifiForm({super.key, required this.payload, required this.onChanged});

  final WifiPayload payload;
  final ValueChanged<WifiPayload> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    final noPass = payload.auth == WifiAuth.nopass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Network name (SSID)',
          initialValue: payload.ssid,
          onChanged: (v) => onChanged(payload.copyWith(ssid: v)),
        ),
        const SizedBox(height: 12),
        if (!noPass) ...[
          AppTextField(
            label: 'Password',
            initialValue: payload.password,
            obscureText: true,
            onChanged: (v) => onChanged(payload.copyWith(password: v)),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<WifiAuth>(
          initialValue: payload.auth,
          decoration: InputDecoration(
            labelText: 'Security',
            labelStyle: TextStyle(color: c.brownLight),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: c.peachLight.withValues(alpha: 0.7)),
            ),
          ),
          items: const [
            DropdownMenuItem(value: WifiAuth.wpa, child: Text('WPA/WPA2')),
            DropdownMenuItem(value: WifiAuth.wep, child: Text('WEP')),
            DropdownMenuItem(value: WifiAuth.nopass, child: Text('None')),
          ],
          onChanged: (v) =>
              onChanged(payload.copyWith(auth: v ?? WifiAuth.wpa)),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: c.peach,
          title: Text('Hidden network', style: TextStyle(color: c.brownDark)),
          value: payload.hidden,
          onChanged: (v) => onChanged(payload.copyWith(hidden: v)),
        ),
      ],
    );
  }
}
