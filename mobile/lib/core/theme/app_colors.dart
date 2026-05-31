import 'package:flutter/material.dart';

/// The QRSafe peach palette. Raw constants only — UI code should read colors
/// from [QRSafeColors] (the [ThemeExtension]) so they stay themeable, but these
/// are the single source of truth the extension is built from.
class AppColors {
  const AppColors._();

  // Peach gradient + warm neutrals.
  static const peachLight = Color(0xFFFFD89C);
  static const peachMid = Color(0xFFFFB68A);
  static const peach = Color(0xFFFF8A6E);
  static const coral = Color(0xFFE96B7A);
  static const cream = Color(0xFFFFF8F0);
  static const brownDark = Color(0xFF3D2E1F);
  static const brownMid = Color(0xFF6B4F33);
  static const brownLight = Color(0xFF8B7A66);
  static const brownTint = Color(0xFFB59474);

  // Verdict colors (foreground + tinted background per state).
  static const safe = Color(0xFF2D8F5C);
  static const safeBg = Color(0xFFDDF5E8);
  static const caution = Color(0xFFB87A2A);
  static const cautionBg = Color(0xFFFFE8D6);
  static const danger = Color(0xFFE26B6B);
  static const dangerBg = Color(0xFFFCE0E0);
  static const unknown = Color(0xFF8B7A66);
  static const unknownBg = Color(0xFFEDE8E0);

  /// The hero / CTA gradient used across the app.
  static const peachGradient = LinearGradient(
    colors: [peachMid, peach, coral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
