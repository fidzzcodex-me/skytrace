import 'package:flutter/material.dart';

import 'colors.dart';
import 'component_styles.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => AppComponents.theme(AppPalette.light, Brightness.light);

  static ThemeData get dark => AppComponents.theme(AppPalette.dark, Brightness.dark);

  static ThemeMode modeFrom(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
