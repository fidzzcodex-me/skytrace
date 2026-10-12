import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/app_logo.dart';
import '../widgets/trace_arc.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(t.t('set_about'))),
      body: Container(
        decoration: BoxDecoration(gradient: AppComponents.skyBackground(p)),
        child: Stack(
          children: [
            const Positioned(top: 0, right: -60, child: TraceArc(size: 260, opacity: 0.25)),
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
