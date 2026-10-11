import 'package:flutter/material.dart';

import 'colors.dart';
import 'text_styles.dart';

class AppComponents {
  const AppComponents._();

  static List<BoxShadow> cardShadow(AppPalette p) => [
        BoxShadow(
          color: p.shadow.withOpacity(0.06),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> softShadow(AppPalette p) => [
        BoxShadow(
          color: p.shadow.withOpacity(0.18),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];

  static BoxDecoration card(AppPalette p) => BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: cardShadow(p),
        border: Border.all(color: p.border.withOpacity(0.6), width: 0.5),
      );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.accentBlue, AppColors.primaryBlue],
  );

  static LinearGradient skyBackground(AppPalette p) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.gradientTop, p.gradientBottom],
      );

  static InputDecoration input(AppPalette p, {String? hint, Widget? prefix, Widget? suffix}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body(p).copyWith(color: p.textSecondary),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border(p.surfaceAlt, 1),
      border: border(p.surfaceAlt, 1),
      focusedBorder: border(AppColors.primaryBlue, 1.5),
    );
  }

  static ThemeData theme(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primaryBlue,
      secondary: AppColors.accentBlue,
      surface: p.surface,
      error: AppColors.errorRed,
      onSurface: p.textPrimary,
    );
    final text = AppText.textTheme(p);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      textTheme: text,
      extensions: [p],
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: p.surfaceAlt.withOpacity(0.5), thickness: 0.5, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.heading(p).copyWith(color: p.brand),
        iconTheme: IconThemeData(color: p.brand),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surface,
        contentTextStyle: AppText.body(p),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.35)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.cloudWhite : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primaryBlue : p.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primaryBlue),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primaryBlue,
        selectionColor: AppColors.accentBlue.withOpacity(0.35),
        selectionHandleColor: AppColors.primaryBlue,
      ),
    );
  }
}
