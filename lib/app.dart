import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/animations.dart';
import 'theme/app_theme.dart';

class SkyTraceApp extends ConsumerWidget {
  const SkyTraceApp({super.key, this.overlay = false});

  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SkyTrace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: (context, child) {
        MotionPrefs.reduce = MediaQuery.disableAnimationsOf(context);
        return child ?? const SizedBox.shrink();
      },
      home: overlay ? const HomeScreen() : const SplashScreen(),
    );
  }
}
