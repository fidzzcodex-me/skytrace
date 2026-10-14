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
import '../utils/strings.dart';
import 'animated_card.dart';
import 'sky_button.dart';

class BubbleSettingsCard extends ConsumerStatefulWidget {
  const BubbleSettingsCard({super.key});

  @override
  ConsumerState<BubbleSettingsCard> createState() => _BubbleSettingsCardState();
}

class _BubbleSettingsCardState extends ConsumerState<BubbleSettingsCard> with WidgetsBindingObserver {
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
      ref.invalidate(bubbleSupportProvider);
      ref.read(trafficRepositoryProvider).bubbleRefresh();
    }
  }

  Future<void> _toggle(bool value, BubbleSupport support) async {
    final repo = ref.read(trafficRepositoryProvider);
    await repo.bubbleSetEnabled(value);
    await ref.read(settingsProvider.notifier).load();
    if (value && support.needsPermission && mounted) {
      await _permissionDialog();
    }
  }

  Future<void> _permissionDialog() async {
    final t = ref.read(stringsProvider);
    await showScaleDialog<void>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return Center(
          child: Material(
            color: p.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              width: 330,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              padding: const EdgeInsets.all(AppSpacing.page + 4),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('bubble_title'), style: AppText.title(p)),
                    const SizedBox(height: 10),
                    Text(t.t('bubble_explain'), style: AppText.body(p).copyWith(fontSize: 13)),
                    const SizedBox(height: 10),
                    Text(t.t('bubble_oem'), style: AppText.caption(p).copyWith(fontSize: 12.5)),
                    const SizedBox(height: 16),
                    SkyButton(
                      label: t.t('bubble_open_settings'),
                      expand: true,
                      icon: const FaIcon(FontAwesomeIcons.gear),
                      onPressed: () {
                        ref.read(trafficRepositoryProvider).openSettings('overlay');
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.t('close'))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _reasonText(Strings t, String reason) {
    switch (reason) {
      case 'api':
        return t.t('bubble_reason_api');
      case 'device':
        return t.t('bubble_reason_device');
      case 'window':
        return t.t('bubble_reason_window');
      case 'settings_api':
        return t.t('bubble_reason_settings_api');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final enabled = ref.watch(settingsProvider.select((s) => s.settings.bubbleEnabled));
    final async = ref.watch(bubbleSupportProvider);

    return AnimatedCard(
      index: 1,
      child: async.when(
        loading: () => Row(
          children: [
            const FaIcon(FontAwesomeIcons.eye, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text(t.t('bubble_toggle'), style: AppText.body(p))),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
          ],
        ),
        error: (e, _) => Text('$e', style: AppText.caption(p).copyWith(color: AppColors.errorRed)),
        data: (support) {
          final Color statusColor;
          final String statusText;
          if (support.supported) {
            statusColor = AppColors.successGreen;
            statusText = t.t('bubble_status_supported');
          } else if (support.needsPermission) {
            statusColor = AppColors.warningAmber;
            statusText = t.t('bubble_status_permission');
          } else {
            statusColor = AppColors.textMuted;
            statusText = t.t('bubble_status_unsupported');
          }
          final reason = support.unsupported ? _reasonText(t, support.reason) : '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.eye, size: 16, color: support.unsupported ? p.textSecondary : AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.t('bubble_toggle'),
                      style: AppText.body(p).copyWith(color: support.unsupported ? p.textSecondary : p.textPrimary),
                    ),
                  ),
                  Switch(
                    value: support.unsupported ? false : enabled,
                    onChanged: support.unsupported ? null : (v) => _toggle(v, support),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(statusText, style: AppText.caption(p).copyWith(color: statusColor, fontSize: 13))),
                ],
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(reason, style: AppText.label(p)),
              ],
              if (support.needsPermission) ...[
                const SizedBox(height: 10),
                SkyButton(
                  label: t.t('bubble_open_settings'),
                  secondary: true,
                  icon: const FaIcon(FontAwesomeIcons.gear),
                  onPressed: _permissionDialog,
                ),
              ],
              if (support.supported) ...[
                const SizedBox(height: 8),
                Text(t.t('bubble_how'), style: AppText.label(p)),
              ],
            ],
          );
        },
      ),
    );
  }
}
