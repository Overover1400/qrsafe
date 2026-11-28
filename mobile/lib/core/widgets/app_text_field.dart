import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A Material 3 text field styled with the teal palette: a soft canvas-tinted
/// fill, brown text, and a brown focus border. Used across the generator forms
/// and edit dialogs so inputs look consistent.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.errorText,
    this.errorMaxLines,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final String? errorText;
  final int? errorMaxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: TextStyle(color: c.inkDark),
      cursorColor: c.inkMid,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        errorMaxLines: errorMaxLines,
        labelStyle: TextStyle(color: c.inkLight),
        floatingLabelStyle: TextStyle(color: c.inkMid),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.tealLight.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.tealLight.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.inkMid, width: 1.6),
        ),
      ),
    );
  }
}
