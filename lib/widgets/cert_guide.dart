import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import 'sky_button.dart';

class CertGuide extends ConsumerStatefulWidget {
  const CertGuide({super.key, this.showTrustNote = true});

  final bool showTrustNote;

  @override
  ConsumerState<CertGuide> createState() => _CertGuideState();
}

class _CertGuideState extends ConsumerState<CertGuide> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(certProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final cert = ref.watch(certProvider);
    final controller = ref.read(certProvider.notifier);
    final p = context.palette;
    final status = cert.status;

    Widget step(int n, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$n', style: AppText.label(p).copyWith(color: AppColors.cloudWhite, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppText.body(p).copyWith(fontSize: 13))),
          ],
        ),
      );
    }

    Widget chip(bool ok, String yes, String no) {
      final color = ok ? AppColors.successGreen : AppColors.warningAmber;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(ok ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleExclamation, size: 12, color: color),
            const SizedBox(width: 6),
            Text(ok ? yes : no, style: AppText.label(p).copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(status.generated, t.t('cert_generated'), t.t('cert_missing')),
            chip(status.installed, t.t('cert_installed'), t.t('cert_not_installed')),
          ],
        ),
        const SizedBox(height: 14),
        step(1, t.t('cert_step1')),
        step(2, t.t('cert_step2_new')),
        step(3, t.t('cert_step3_new')),
        step(4, t.t('cert_step4')),
        if (status.generated) ...[
          const SizedBox(height: 4),
          Text(t.t('cert_fingerprint'), style: AppText.label(p)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: status.fingerprint));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('copied')), duration: const Duration(seconds: 1)));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.inner),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.control)),
              child: Text(status.fingerprint, style: AppText.mono(p, size: 10.5)),
            ),
          ),
          if (status.notAfter > 0) ...[
            const SizedBox(height: 6),
            Text(Fmt.dateTime(status.notAfter), style: AppText.label(p)),
          ],
        ],
        if (cert.savedTo.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${t.t('cert_saved_to')}: ${cert.savedTo}', style: AppText.caption(p)),
        ],
        if (cert.error != null) ...[
          const SizedBox(height: 10),
          Text(cert.error!, style: AppText.caption(p).copyWith(color: AppColors.errorRed)),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!status.generated)
              SkyButton(
                label: t.t('cert_generate'),
                icon: const FaIcon(FontAwesomeIcons.certificate),
                loading: cert.busy,
                onPressed: controller.generate,
              )
            else ...[
              SkyButton(
                label: t.t('cert_install'),
                icon: const FaIcon(FontAwesomeIcons.lockOpen),
                loading: cert.busy,
                onPressed: controller.install,
              ),
              SkyButton(
                label: t.t('cert_share'),
                secondary: true,
                icon: const FaIcon(FontAwesomeIcons.share),
                onPressed: cert.busy ? null : controller.share,
              ),
              SkyButton(
                label: t.t('cert_refresh'),
                secondary: true,
                icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
                onPressed: cert.busy ? null : controller.refresh,
              ),
            ],
          ],
        ),
        if (widget.showTrustNote) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.inner),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: FaIcon(FontAwesomeIcons.circleInfo, size: 14, color: AppColors.warningAmber),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(t.t('cert_trust_note'), style: AppText.caption(p).copyWith(fontSize: 12.5))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
