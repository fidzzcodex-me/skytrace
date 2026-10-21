import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'animated_card.dart';
import 'text_dialog.dart';

class AdblockSettingsCard extends ConsumerWidget {
  const AdblockSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final s = ref.watch(settingsProvider).settings;
    final controller = ref.read(settingsProvider.notifier);

    Widget switchRow(String label, IconData icon, bool value, String key) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 22, child: FaIcon(icon, size: 15, color: AppColors.primaryBlue)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppText.body(p))),
            Switch(value: value, onChanged: (v) => controller.update({key: v})),
          ],
        ),
      );
    }

    Widget listRow(String label, String value, String key, IconData icon) {
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () async {
          final v = await showTextListDialog(
            context,
            title: label,
            initial: value,
            hint: t.t('adblock_list_hint'),
            strings: t,
          );
          if (v != null) await controller.update({key: v});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 22, child: FaIcon(icon, size: 15, color: AppColors.primaryBlue)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppText.body(p))),
              Text('${countEntries(value)}', style: AppText.mono(p, size: 13).copyWith(color: p.textSecondary)),
            ],
          ),
        ),
      );
    }

    return AnimatedCard(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switchRow(t.t('adblock_enable'), FontAwesomeIcons.shieldHalved, s.adblockEnabled, 'adblockEnabled'),
          const SizedBox(height: 4),
          Text(t.t('adblock_note'), style: AppText.label(p)),
          if (s.adblockEnabled) ...[
            const Divider(height: 22),
            switchRow(t.t('adblock_ads'), FontAwesomeIcons.ban, s.adblockAds, 'adblockAds'),
            switchRow(t.t('adblock_trackers'), FontAwesomeIcons.eye, s.adblockTrackers, 'adblockTrackers'),
            const Divider(height: 18),
            listRow(t.t('adblock_custom'), s.adblockCustom, 'adblockCustom', FontAwesomeIcons.list),
            listRow(t.t('adblock_allow'), s.adblockAllow, 'adblockAllow', FontAwesomeIcons.circleCheck),
          ],
        ],
      ),
    );
  }
}
