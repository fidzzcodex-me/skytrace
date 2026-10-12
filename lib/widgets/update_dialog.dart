import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_info.dart';
import '../providers/core_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/app_config.dart';
import 'sky_button.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info, String current) {
  return showScaleDialog<void>(
    context: context,
    builder: (_) => _UpdateDialog(info: info, current: current),
  );
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.info, required this.current});

  final UpdateInfo info;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final notes = info.notes.isEmpty ? '-' : info.notes;

    return Center(
      child: Material(
        color: p.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        child: Container(
          width: 340,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(AppSpacing.page + 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const FaIcon(FontAwesomeIcons.download, size: 18, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t.t('update_title'), style: AppText.title(p))),
                ],
              ),
              const SizedBox(height: 14),
              Text('${t.t('update_version')}: v${info.version}', style: AppText.bodyMedium(p)),
              Text('${t.t('update_current')}: v$current', style: AppText.caption(p)),
              const SizedBox(height: 14),
              Text(t.t('update_notes'), style: AppText.label(p)),
              const SizedBox(height: 6),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.inner),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: SingleChildScrollView(child: SelectableText(notes, style: AppText.body(p).copyWith(fontSize: 13))),
                ),
              ),
              const SizedBox(height: 16),
              SkyButton(
                label: t.t('update_download'),
                expand: true,
                icon: const FaIcon(FontAwesomeIcons.download),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await ref.read(trafficRepositoryProvider).openUrl(info.apkUrl ?? info.pageUrl.ifEmpty(kReleasesUrl));
                  nav.pop();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await ref.read(updateProvider.notifier).skip(info.version);
                        nav.pop();
                      },
                      child: Text(t.t('update_skip')),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.t('update_later')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
