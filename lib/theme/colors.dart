import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primaryBlue = Color(0xFF4A90E2);
  static const Color softSky = Color(0xFFE8F4FD);
  static const Color cloudWhite = Color(0xFFFFFFFF);
  static const Color accentBlue = Color(0xFF87CEEB);
  static const Color deepBlue = Color(0xFF2C5F9E);
  static const Color skyGradientTop = Color(0xFFE3F2FD);
  static const Color skyGradientBottom = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A2B4A);
  static const Color textMuted = Color(0xFF7A8FA6);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color errorRed = Color(0xFFE53935);

  static const Color nightBackground = Color(0xFF0E1A2B);
  static const Color nightSurface = Color(0xFF15253B);
  static const Color nightSurfaceAlt = Color(0xFF1C3250);
  static const Color nightText = Color(0xFFE6EEF8);
  static const Color nightMuted = Color(0xFF8FA3BC);
}

class AppSpacing {
  const AppSpacing._();

  static const double page = 16;
  static const double cardGap = 12;
  static const double tight = 8;
  static const double inner = 12;
  static const double navHeight = 60;
  static const double logoAppBar = 28;
}

class AppRadius {
  const AppRadius._();

  static const double card = 16;
  static const double control = 12;
  static const double dialog = 20;
  static const double pill = 999;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 250);
  static const Duration base = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;
  static const Duration stagger = Duration(milliseconds: 40);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.gradientTop,
    required this.gradientBottom,
    required this.shadow,
    required this.brand,
    required this.brandStrong,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color gradientTop;
  final Color gradientBottom;
  final Color shadow;
  final Color brand;
  final Color brandStrong;

  static const AppPalette light = AppPalette(
    background: AppColors.cloudWhite,
    surface: AppColors.cloudWhite,
    surfaceAlt: AppColors.softSky,
    border: AppColors.softSky,
    textPrimary: AppColors.textDark,
    textSecondary: AppColors.textMuted,
    gradientTop: AppColors.skyGradientTop,
    gradientBottom: AppColors.skyGradientBottom,
    shadow: AppColors.primaryBlue,
    brand: AppColors.primaryBlue,
    brandStrong: AppColors.deepBlue,
  );

  static const AppPalette dark = AppPalette(
    background: AppColors.nightBackground,
    surface: AppColors.nightSurface,
    surfaceAlt: AppColors.nightSurfaceAlt,
    border: AppColors.nightSurfaceAlt,
    textPrimary: AppColors.nightText,
    textSecondary: AppColors.nightMuted,
    gradientTop: AppColors.nightSurfaceAlt,
    gradientBottom: AppColors.nightBackground,
    shadow: Color(0xFF000000),
    brand: AppColors.accentBlue,
    brandStrong: AppColors.primaryBlue,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? gradientTop,
    Color? gradientBottom,
    Color? shadow,
    Color? brand,
    Color? brandStrong,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      gradientTop: gradientTop ?? this.gradientTop,
      gradientBottom: gradientBottom ?? this.gradientBottom,
      shadow: shadow ?? this.shadow,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      gradientTop: Color.lerp(gradientTop, other.gradientTop, t)!,
      gradientBottom: Color.lerp(gradientBottom, other.gradientBottom, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
