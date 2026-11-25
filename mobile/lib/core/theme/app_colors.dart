import 'package:flutter/material.dart';

/// The QRSafe teal palette. Raw constants only — UI code should read colors
/// from [QRSafeColors] (the [ThemeExtension]) so they stay themeable, but these
/// are the single source of truth the extension is built from.
class AppColors {
  const AppColors._();

  // Green-blue gradient + cool neutrals.
  static const tealLight = Color(0xFF7FE3D0);
  static const tealMid = Color(0xFF3FC9C0);
  static const teal = Color(0xFF14A89C);
  static const accent = Color(0xFF0E7C8A);
  static const canvas = Color(0xFFF1FAF8);
  static const inkDark = Color(0xFF0F3B3F);
  static const inkMid = Color(0xFF2C5A60);
  static const inkLight = Color(0xFF5E8A8E);
  static const inkTint = Color(0xFF9FC2C4);

  // Verdict colors (foreground + tinted background per state).
  static const safe = Color(0xFF1E9E6A);
  static const safeBg = Color(0xFFD8F4E7);
  static const caution = Color(0xFFB8781F);
  static const cautionBg = Color(0xFFFCEBD2);
  static const danger = Color(0xFFD95757);
  static const dangerBg = Color(0xFFFBE0E0);
  static const unknown = Color(0xFF5E8A8E);
  static const unknownBg = Color(0xFFE4EEEE);

  /// The hero / CTA gradient used across the app.
  static const tealGradient = LinearGradient(
    colors: [tealMid, teal, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
