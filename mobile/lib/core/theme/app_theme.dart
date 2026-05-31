import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Themeable container for the QRSafe palette. Widgets read colors via
/// `Theme.of(context).extension<QRSafeColors>()!` rather than touching
/// [AppColors] directly, so a dark/alternate theme can swap the whole set later.
@immutable
class QRSafeColors extends ThemeExtension<QRSafeColors> {
  const QRSafeColors({
    required this.peachLight,
    required this.peachMid,
    required this.peach,
    required this.coral,
    required this.cream,
    required this.brownDark,
    required this.brownMid,
    required this.brownLight,
    required this.brownTint,
    required this.safe,
    required this.safeBg,
    required this.caution,
    required this.cautionBg,
    required this.danger,
    required this.dangerBg,
    required this.unknown,
    required this.unknownBg,
    required this.peachGradient,
  });

  final Color peachLight;
  final Color peachMid;
  final Color peach;
  final Color coral;
  final Color cream;
  final Color brownDark;
  final Color brownMid;
  final Color brownLight;
  final Color brownTint;
  final Color safe;
  final Color safeBg;
  final Color caution;
  final Color cautionBg;
  final Color danger;
  final Color dangerBg;
  final Color unknown;
  final Color unknownBg;
  final LinearGradient peachGradient;

  /// The default light QRSafe palette, built from [AppColors].
  static const light = QRSafeColors(
    peachLight: AppColors.peachLight,
    peachMid: AppColors.peachMid,
    peach: AppColors.peach,
    coral: AppColors.coral,
    cream: AppColors.cream,
    brownDark: AppColors.brownDark,
    brownMid: AppColors.brownMid,
    brownLight: AppColors.brownLight,
    brownTint: AppColors.brownTint,
    safe: AppColors.safe,
    safeBg: AppColors.safeBg,
    caution: AppColors.caution,
    cautionBg: AppColors.cautionBg,
    danger: AppColors.danger,
    dangerBg: AppColors.dangerBg,
    unknown: AppColors.unknown,
    unknownBg: AppColors.unknownBg,
    peachGradient: AppColors.peachGradient,
  );

  @override
  QRSafeColors copyWith({
    Color? peachLight,
    Color? peachMid,
    Color? peach,
    Color? coral,
    Color? cream,
    Color? brownDark,
    Color? brownMid,
    Color? brownLight,
    Color? brownTint,
    Color? safe,
    Color? safeBg,
    Color? caution,
    Color? cautionBg,
    Color? danger,
    Color? dangerBg,
    Color? unknown,
    Color? unknownBg,
    LinearGradient? peachGradient,
  }) {
    return QRSafeColors(
      peachLight: peachLight ?? this.peachLight,
      peachMid: peachMid ?? this.peachMid,
      peach: peach ?? this.peach,
      coral: coral ?? this.coral,
      cream: cream ?? this.cream,
      brownDark: brownDark ?? this.brownDark,
      brownMid: brownMid ?? this.brownMid,
      brownLight: brownLight ?? this.brownLight,
      brownTint: brownTint ?? this.brownTint,
      safe: safe ?? this.safe,
      safeBg: safeBg ?? this.safeBg,
      caution: caution ?? this.caution,
      cautionBg: cautionBg ?? this.cautionBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      unknown: unknown ?? this.unknown,
      unknownBg: unknownBg ?? this.unknownBg,
      peachGradient: peachGradient ?? this.peachGradient,
    );
  }

  @override
  QRSafeColors lerp(ThemeExtension<QRSafeColors>? other, double t) {
    if (other is! QRSafeColors) return this;
    return QRSafeColors(
      peachLight: Color.lerp(peachLight, other.peachLight, t)!,
      peachMid: Color.lerp(peachMid, other.peachMid, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      brownDark: Color.lerp(brownDark, other.brownDark, t)!,
      brownMid: Color.lerp(brownMid, other.brownMid, t)!,
      brownLight: Color.lerp(brownLight, other.brownLight, t)!,
      brownTint: Color.lerp(brownTint, other.brownTint, t)!,
      safe: Color.lerp(safe, other.safe, t)!,
      safeBg: Color.lerp(safeBg, other.safeBg, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      cautionBg: Color.lerp(cautionBg, other.cautionBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      unknownBg: Color.lerp(unknownBg, other.unknownBg, t)!,
      peachGradient: LinearGradient.lerp(peachGradient, other.peachGradient, t)!,
    );
  }
}

/// Convenience accessor: `context.qrColors` instead of the verbose
/// `Theme.of(context).extension<QRSafeColors>()!`.
extension QRSafeColorsX on BuildContext {
  QRSafeColors get qrColors => Theme.of(this).extension<QRSafeColors>()!;
}

/// Builds the app-wide [ThemeData]: cream surfaces, brown text, peach seed,
/// and the [QRSafeColors] extension attached.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.peach,
          brightness: Brightness.light,
        ).copyWith(
          surface: AppColors.cream,
          primary: AppColors.peach,
          onPrimary: Colors.white,
          onSurface: AppColors.brownDark,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      // System default font (Roboto on Android, San Francisco on iOS).
      fontFamily: null,
      extensions: const [QRSafeColors.light],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.brownDark,
        displayColor: AppColors.brownDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.brownDark,
        elevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.peachMid,
        contentTextStyle: TextStyle(color: AppColors.brownDark),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
