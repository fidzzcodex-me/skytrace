import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/sky.dart';
import '../theme/text_styles.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(t.t('set_about'))),
      body: SkyScene(
        mood: SkyMood.brightening,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.page * 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(variant: LogoVariant.vertical, height: 200, hero: false).scaleIn(),
                    const SizedBox(height: 24),
                    Text('${t.t('about_version')} ${ref.watch(appVersionProvider).valueOrNull ?? ''}', style: AppText.bodyMedium(p)).fadeInUp(index: 2),
                    const SizedBox(height: 12),
                    Text(
                      t.t('about_desc'),
                      textAlign: TextAlign.center,
                      style: AppText.body(p).copyWith(color: p.textSecondary),
                    ).fadeInUp(index: 3),
                    const SizedBox(height: 8),
                    Text(
                      t.t('about_stack'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(p),
                    ).fadeInUp(index: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
