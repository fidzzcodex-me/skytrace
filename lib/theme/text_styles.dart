import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppText {
  const AppText._();

  static const List<String> fallback = ['Inter', 'Poppins'];

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.35,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: fallback);
  }

  static TextStyle display(AppPalette p) =>
      _base(size: 32, weight: FontWeight.w700, color: p.textPrimary, height: 1.15, letterSpacing: -0.4);

  static TextStyle numeric(AppPalette p, {double size = 48}) => _base(
        size: size,
        weight: FontWeight.w700,
        color: p.textPrimary,
        height: 1,
        letterSpacing: -1,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle title(AppPalette p) =>
      _base(size: 20, weight: FontWeight.w700, color: p.textPrimary, height: 1.25);

  static TextStyle heading(AppPalette p) =>
      _base(size: 16, weight: FontWeight.w600, color: p.textPrimary);

  static TextStyle body(AppPalette p) =>
      _base(size: 14, weight: FontWeight.w400, color: p.textPrimary);

  static TextStyle bodyMedium(AppPalette p) =>
      _base(size: 14, weight: FontWeight.w500, color: p.textPrimary);

  static TextStyle caption(AppPalette p) =>
      _base(size: 12, weight: FontWeight.w400, color: p.textSecondary);

  static TextStyle label(AppPalette p) =>
      _base(size: 11, weight: FontWeight.w500, color: p.textSecondary, letterSpacing: 0.2);

  static TextStyle button() =>
      _base(size: 14, weight: FontWeight.w600, color: AppColors.cloudWhite, letterSpacing: 0.1);

  static TextStyle mono(AppPalette p, {double size = 12}) => TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        height: 1.45,
        color: p.textPrimary,
      );

  static TextTheme textTheme(AppPalette p) => TextTheme(
        displaySmall: display(p),
        titleLarge: title(p),
        titleMedium: heading(p),
        bodyLarge: body(p),
        bodyMedium: body(p),
        bodySmall: caption(p),
        labelLarge: bodyMedium(p),
        labelSmall: label(p),
      );
}
