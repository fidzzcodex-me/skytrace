import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../widgets/cert_guide.dart';

class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(t.t('cert_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.page),
          decoration: AppComponents.card(p),
          child: const CertGuide(),
        ),
      ),
    );
  }
}
