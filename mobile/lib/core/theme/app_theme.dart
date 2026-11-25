import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Themeable container for the QRSafe palette. Widgets read colors via
/// `Theme.of(context).extension<QRSafeColors>()!` rather than touching
/// [AppColors] directly, so a dark/alternate theme can swap the whole set later.
@immutable
class QRSafeColors extends ThemeExtension<QRSafeColors> {
  const QRSafeColors({
    required this.tealLight,
    required this.tealMid,
    required this.teal,
    required this.accent,
    required this.canvas,
    required this.inkDark,
    required this.inkMid,
    required this.inkLight,
    required this.inkTint,
    required this.safe,
    required this.safeBg,
    required this.caution,
    required this.cautionBg,
    required this.danger,
    required this.dangerBg,
    required this.unknown,
    required this.unknownBg,
    required this.tealGradient,
  });

  final Color tealLight;
  final Color tealMid;
  final Color teal;
  final Color accent;
  final Color canvas;
  final Color inkDark;
  final Color inkMid;
  final Color inkLight;
  final Color inkTint;
  final Color safe;
  final Color safeBg;
  final Color caution;
  final Color cautionBg;
  final Color danger;
  final Color dangerBg;
  final Color unknown;
  final Color unknownBg;
  final LinearGradient tealGradient;

  /// The default light QRSafe palette, built from [AppColors].
  static const light = QRSafeColors(
    tealLight: AppColors.tealLight,
    tealMid: AppColors.tealMid,
    teal: AppColors.teal,
    accent: AppColors.accent,
    canvas: AppColors.canvas,
    inkDark: AppColors.inkDark,
    inkMid: AppColors.inkMid,
    inkLight: AppColors.inkLight,
    inkTint: AppColors.inkTint,
    safe: AppColors.safe,
    safeBg: AppColors.safeBg,
    caution: AppColors.caution,
    cautionBg: AppColors.cautionBg,
    danger: AppColors.danger,
    dangerBg: AppColors.dangerBg,
    unknown: AppColors.unknown,
    unknownBg: AppColors.unknownBg,
    tealGradient: AppColors.tealGradient,
  );

  @override
  QRSafeColors copyWith({
    Color? tealLight,
    Color? tealMid,
    Color? teal,
    Color? accent,
    Color? canvas,
    Color? inkDark,
    Color? inkMid,
    Color? inkLight,
    Color? inkTint,
    Color? safe,
    Color? safeBg,
    Color? caution,
    Color? cautionBg,
    Color? danger,
    Color? dangerBg,
    Color? unknown,
    Color? unknownBg,
    LinearGradient? tealGradient,
  }) {
    return QRSafeColors(
      tealLight: tealLight ?? this.tealLight,
      tealMid: tealMid ?? this.tealMid,
      teal: teal ?? this.teal,
      accent: accent ?? this.accent,
      canvas: canvas ?? this.canvas,
      inkDark: inkDark ?? this.inkDark,
      inkMid: inkMid ?? this.inkMid,
      inkLight: inkLight ?? this.inkLight,
      inkTint: inkTint ?? this.inkTint,
      safe: safe ?? this.safe,
      safeBg: safeBg ?? this.safeBg,
      caution: caution ?? this.caution,
      cautionBg: cautionBg ?? this.cautionBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      unknown: unknown ?? this.unknown,
      unknownBg: unknownBg ?? this.unknownBg,
      tealGradient: tealGradient ?? this.tealGradient,
    );
  }

  @override
  QRSafeColors lerp(ThemeExtension<QRSafeColors>? other, double t) {
    if (other is! QRSafeColors) return this;
    return QRSafeColors(
      tealLight: Color.lerp(tealLight, other.tealLight, t)!,
      tealMid: Color.lerp(tealMid, other.tealMid, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      inkDark: Color.lerp(inkDark, other.inkDark, t)!,
      inkMid: Color.lerp(inkMid, other.inkMid, t)!,
      inkLight: Color.lerp(inkLight, other.inkLight, t)!,
      inkTint: Color.lerp(inkTint, other.inkTint, t)!,
      safe: Color.lerp(safe, other.safe, t)!,
      safeBg: Color.lerp(safeBg, other.safeBg, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      cautionBg: Color.lerp(cautionBg, other.cautionBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      unknownBg: Color.lerp(unknownBg, other.unknownBg, t)!,
      tealGradient: LinearGradient.lerp(tealGradient, other.tealGradient, t)!,
    );
  }
}

/// Convenience accessor: `context.qrColors` instead of the verbose
/// `Theme.of(context).extension<QRSafeColors>()!`.
extension QRSafeColorsX on BuildContext {
  QRSafeColors get qrColors => Theme.of(this).extension<QRSafeColors>()!;
}

/// Builds the app-wide [ThemeData]: canvas surfaces, brown text, teal seed,
/// and the [QRSafeColors] extension attached.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          brightness: Brightness.light,
        ).copyWith(
          surface: AppColors.canvas,
          primary: AppColors.teal,
          onPrimary: Colors.white,
          onSurface: AppColors.inkDark,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      // System default font (Roboto on Android, San Francisco on iOS).
      fontFamily: null,
      extensions: const [QRSafeColors.light],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.inkDark,
        displayColor: AppColors.inkDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.inkDark,
        elevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.tealMid,
        contentTextStyle: TextStyle(color: AppColors.inkDark),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
