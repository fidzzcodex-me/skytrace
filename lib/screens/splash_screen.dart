import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/sky.dart';
import '../theme/text_styles.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  bool _navigated = false;
  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      _minElapsed = true;
      _tryNavigate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tryNavigate() {
    if (_navigated || !mounted || !_minElapsed) return;
    final state = ref.read(settingsProvider);
    if (!state.loaded) return;
    _navigated = true;
    final target = state.settings.onboardingDone ? const HomeScreen() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(FadeRoute<void>(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, __) => _tryNavigate());
    final palette = AppPalette.light;
    return Scaffold(
      body: SkyScene(
        mood: SkyMood.clear,
        forceLight: true,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.page * 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(variant: LogoVariant.vertical, height: 190).scaleIn(),
                      const SizedBox(height: 20),
                      Text(
                        'Intercept  Inspect  Modify  Replay',
                        style: AppText.caption(palette).copyWith(letterSpacing: 0.6),
                      ).fadeInUp(index: 3),
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primaryBlue),
                      ).fadeInSoft(delay: const Duration(milliseconds: 500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
