import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/animated_card.dart';
import '../widgets/section_header.dart';
import 'about_screen.dart';
import 'certificate_screen.dart';
import 'diagnostics_screen.dart';
import 'logs_screen.dart';
import 'monitor_screen.dart';
import 'target_apps_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<String?> _askText(BuildContext context, String title, String initial, {bool number = false, int maxLines = 1, String? hint}) {
    final controller = TextEditingController(text: initial);
    return showScaleDialog<String>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return Center(
          child: Material(
            color: p.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(AppSpacing.page + 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.heading(p)),
                  const SizedBox(height: 12),
                  if (hint != null) ...[
                    Text(hint, style: AppText.label(p)),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: maxLines > 1 ? 4 : 1,
                    maxLines: maxLines,
                    keyboardType: number ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
                    style: AppText.mono(p, size: 14),
                    decoration: AppComponents.input(p),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('OK')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _valueRow(BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(width: 22, child: FaIcon(icon, size: 15, color: AppColors.primaryBlue)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(label, style: AppText.body(p))),
            Text(value, style: AppText.mono(p, size: 12.5).copyWith(color: p.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(width: 22, child: FaIcon(icon, size: 15, color: AppColors.primaryBlue)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(label, style: AppText.body(p))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(settingsProvider).settings;
    final controller = ref.read(settingsProvider.notifier);
    final p = context.palette;

    Future<void> editNumber(String key, String label, int current) async {
      final v = await _askText(context, label, '$current', number: true);
      final n = int.tryParse(v ?? '');
      if (n != null) await controller.update({key: n});
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      cacheExtent: 800,
      children: [
        SectionHeader(title: t.t('set_capture')),
        AnimatedCard(
          index: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.tight),
          child: Column(
            children: [
              _valueRow(
                context,
                label: t.t('target_title'),
                value: s.targetApps.isEmpty ? t.t('target_all') : '${s.targetApps.length}',
                icon: FontAwesomeIcons.mobileScreen,
                onTap: () => Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const TargetAppsScreen())),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_dns'),
                value: s.dns,
                icon: FontAwesomeIcons.globe,
                onTap: () async {
                  final v = await _askText(context, t.t('set_dns'), s.dns);
                  if (v != null && v.isNotEmpty) await controller.update({'dns': v});
                },
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_connect_timeout'),
                value: '${s.connectTimeoutMs}',
                icon: FontAwesomeIcons.hourglass,
                onTap: () => editNumber('connectTimeoutMs', t.t('set_connect_timeout'), s.connectTimeoutMs),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_read_timeout'),
                value: '${s.readTimeoutMs}',
                icon: FontAwesomeIcons.clock,
                onTap: () => editNumber('readTimeoutMs', t.t('set_read_timeout'), s.readTimeoutMs),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_max_body'),
                value: '${s.maxBodyKb}',
                icon: FontAwesomeIcons.fileLines,
                onTap: () => editNumber('maxBodyKb', t.t('set_max_body'), s.maxBodyKb),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_max_entries'),
                value: '${s.maxEntries}',
                icon: FontAwesomeIcons.list,
                onTap: () => editNumber('maxEntries', t.t('set_max_entries'), s.maxEntries),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_bp_timeout'),
                value: '${s.breakpointTimeoutSec}',
                icon: FontAwesomeIcons.pause,
                onTap: () => editNumber('breakpointTimeoutSec', t.t('set_bp_timeout'), s.breakpointTimeoutSec),
              ),
              const Divider(),
              _switchRow(
                context,
                label: t.t('set_tls'),
                icon: FontAwesomeIcons.lock,
                value: s.tlsInterception,
                onChanged: (v) => controller.update({'tlsInterception': v}),
              ),
              _switchRow(
                context,
                label: t.t('set_block_quic'),
                icon: FontAwesomeIcons.ban,
                value: s.blockQuic,
                onChanged: (v) => controller.update({'blockQuic': v}),
              ),
              _switchRow(
                context,
                label: t.t('set_normalize'),
                icon: FontAwesomeIcons.code,
                value: s.normalizeEncoding,
                onChanged: (v) => controller.update({'normalizeEncoding': v}),
              ),
              _switchRow(
                context,
                label: t.t('set_ignore_cert'),
                icon: FontAwesomeIcons.lockOpen,
                value: s.ignoreUpstreamCertErrors,
                onChanged: (v) => controller.update({'ignoreUpstreamCertErrors': v}),
              ),
              _switchRow(
                context,
                label: t.t('set_clear_start'),
                icon: FontAwesomeIcons.trash,
                value: s.clearOnStart,
                onChanged: (v) => controller.update({'clearOnStart': v}),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(t.t('set_note_restart'), style: AppText.label(p)),
              ),
            ],
          ),
        ),
        SectionHeader(title: t.t('set_proxy')),
        AnimatedCard(
          index: 1,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.tight),
          child: Column(
            children: [
              _valueRow(
                context,
                label: t.t('set_proxy_port'),
                value: '${s.proxyPort}',
                icon: FontAwesomeIcons.globe,
                onTap: () => editNumber('proxyPort', t.t('set_proxy_port'), s.proxyPort),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_proxy_auth'),
                value: s.proxyAuth.isEmpty ? '-' : '****',
                icon: FontAwesomeIcons.key,
                onTap: () async {
                  final v = await _askText(context, t.t('set_proxy_auth'), s.proxyAuth);
                  if (v != null) await controller.update({'proxyAuth': v});
                },
              ),
              const Divider(),
              _switchRow(
                context,
                label: t.t('set_proxy_all'),
                icon: FontAwesomeIcons.signal,
                value: s.proxyBindAll,
                onChanged: (v) => controller.update({'proxyBindAll': v}),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_bypass'),
                value: '${s.bypassHosts.split(RegExp(r'[\n,; ]+')).where((e) => e.trim().isNotEmpty).length}',
                icon: FontAwesomeIcons.ban,
                onTap: () async {
                  final v = await _askText(
                    context,
                    t.t('set_bypass'),
                    s.bypassHosts,
                    maxLines: 8,
                    hint: t.t('set_bypass_hint'),
                  );
                  if (v != null) await controller.update({'bypassHosts': v});
                },
              ),
            ],
          ),
        ),
        SectionHeader(title: t.t('set_appearance')),
        AnimatedCard(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.t('set_theme'), style: AppText.label(p)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'system', label: Text(t.t('theme_system'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'light', label: Text(t.t('theme_light'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'dark', label: Text(t.t('theme_dark'), style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {s.theme},
                  onSelectionChanged: (v) => controller.update({'theme': v.first}),
                ),
              ),
              const SizedBox(height: 16),
              Text(t.t('set_language'), style: AppText.label(p)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'id', label: Text('Bahasa Indonesia')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {s.language},
                  onSelectionChanged: (v) => controller.update({'language': v.first}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        AnimatedCard(
          index: 2,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.tight),
          child: Column(
            children: [
              _valueRow(
                context,
                label: t.t('set_update'),
                value: ref.watch(appVersionProvider).valueOrNull ?? '',
                icon: FontAwesomeIcons.download,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final controller = ref.read(updateProvider.notifier);
                  await controller.check(manual: true);
                  final state = ref.read(updateProvider);
                  if (state.error != null) {
                    messenger.showSnackBar(SnackBar(content: Text(t.t('update_error'))));
                  } else if (state.upToDate) {
                    messenger.showSnackBar(SnackBar(content: Text(t.t('update_none'))));
                  }
                },
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_certificate'),
                value: '',
                icon: FontAwesomeIcons.certificate,
                onTap: () => Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const CertificateScreen())),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('monitor_title'),
                value: '',
                icon: FontAwesomeIcons.globe,
                onTap: () => Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const MonitorScreen())),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('diag_title'),
                value: '',
                icon: FontAwesomeIcons.gauge,
                onTap: () => Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const DiagnosticsScreen())),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_logs'),
                value: '',
                icon: FontAwesomeIcons.fileCode,
                onTap: () => Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const LogsScreen())),
              ),
              const Divider(),
              _valueRow(
                context,
                label: t.t('set_about'),
                value: '',
                icon: FontAwesomeIcons.circleInfo,
                onTap: () => Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const AboutScreen())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const _SettingsTitle()),
      body: const SettingsScreen(),
    );
  }
}

class _SettingsTitle extends ConsumerWidget {
  const _SettingsTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(ref.watch(stringsProvider).t('nav_settings'));
  }
}
