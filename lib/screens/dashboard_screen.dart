import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_info.dart';
import '../providers/core_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_provider.dart';
import '../providers/update_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/sky.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import '../utils/strings.dart';
import '../widgets/animated_card.dart';
import '../widgets/request_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/sky_button.dart';
import '../widgets/stat_tile.dart';
import 'breakpoint_screen.dart';
import 'certificate_screen.dart';
import 'monitor_screen.dart';
import 'target_apps_screen.dart';
import 'traffic_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onOpenTraffic, required this.onOpenRules});

  final VoidCallback onOpenTraffic;
  final VoidCallback onOpenRules;

  String _phaseText(VpnPhase phase, Strings t) {
    switch (phase) {
      case VpnPhase.stopped:
        return t.t('vpn_stopped');
      case VpnPhase.starting:
        return t.t('vpn_starting');
      case VpnPhase.running:
        return t.t('vpn_running');
      case VpnPhase.stopping:
        return t.t('vpn_stopping');
      case VpnPhase.error:
        return t.t('vpn_error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final vpn = ref.watch(vpnProvider);
    final pending = ref.watch(rulesProvider.select((s) => s.pending));
    final recent = ref.watch(trafficProvider.select((s) => s.items)).take(5).toList();
    final p = context.palette;

    Future<void> toggle() async {
      final messenger = ScaffoldMessenger.of(context);
      final error = await ref.read(vpnProvider.notifier).toggle();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error == 'vpn_denied' ? t.t('vpn_denied') : error)));
      }
    }

    final targets = ref.watch(settingsProvider.select((s) => s.settings.targetApps));
    final mode = ref.watch(settingsProvider.select((s) => s.settings.captureMode));
    final running = vpn.isRunning;
    final batteryExempt = ref.watch(batteryExemptProvider).valueOrNull ?? true;
    final batteryDismissed = ref.watch(batteryBannerDismissedProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      cacheExtent: 600,
      children: [
        if (!batteryExempt && !batteryDismissed) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.page),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.bolt, size: 16, color: AppColors.warningAmber),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.t('battery_title'), style: AppText.heading(p))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(t.t('battery_body'), style: AppText.caption(p).copyWith(fontSize: 12.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SkyButton(
                        label: t.t('battery_open'),
                        icon: const FaIcon(FontAwesomeIcons.gear),
                        onPressed: () => ref.read(trafficRepositoryProvider).openSettings('battery'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => ref.read(batteryBannerDismissedProvider.notifier).state = true,
                      child: Text(t.t('battery_later')),
                    ),
                  ],
                ),
              ],
            ),
          ).fadeInUp(),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        SkyScene(
          mood: _moodFor(vpn),
          borderRadius: BorderRadius.circular(AppRadius.card + 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card + 8),
              border: Border.all(color: p.border),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatePill(
                      label: running && vpn.paused ? t.t('rec_paused') : _phaseText(vpn.phase, t),
                      color: _pillColor(vpn),
                      active: running && !vpn.paused,
                    ),
                    const Spacer(),
                    _HeroChip(
                      icon: mode == 'proxy' ? FontAwesomeIcons.globe : FontAwesomeIcons.shieldHalved,
                      label: mode == 'proxy' ? t.t('mode_proxy') : t.t('mode_vpn'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('${vpn.requests}', style: AppText.numeric(p)),
                const SizedBox(height: 6),
                Text(t.t('requests'), style: AppText.caption(p).copyWith(fontSize: 13, color: p.textPrimary, fontWeight: FontWeight.w500)),
                if (vpn.phase == VpnPhase.error && vpn.error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(vpn.error, style: AppText.caption(p).copyWith(color: AppColors.errorRed, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 20),
                SkyButton(
                  label: running ? t.t('vpn_stop') : t.t('vpn_start'),
                  expand: true,
                  loading: vpn.isBusy,
                  secondary: running,
                  danger: running,
                  icon: const FaIcon(FontAwesomeIcons.powerOff),
                  onPressed: toggle,
                ),
              ],
            ),
          ),
        ).fadeInUp(),
        const SizedBox(height: AppSpacing.cardGap),
        _ModeSelector(
          mode: mode,
          locked: vpn.isRunning || vpn.isBusy,
          strings: t,
          onChanged: (value) => ref.read(settingsProvider.notifier).update({'captureMode': value}),
        ).fadeInUp(index: 1),
        const SizedBox(height: AppSpacing.cardGap),
        if (mode == 'proxy')
          const _ProxyCard()
        else
          AnimatedCard(
          index: 1,
          onTap: () => Navigator.of(context).push(
            SlideFromRightRoute<void>(builder: (_) => const TargetAppsScreen()),
          ),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.mobileScreen, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('target_title'), style: AppText.label(p)),
                    Text(
                      targets.isEmpty ? t.t('target_all') : '${targets.length} ${t.t('target_count')}',
                      style: AppText.bodyMedium(p),
                    ),
                  ],
                ),
              ),
              const FaIcon(FontAwesomeIcons.arrowRight, size: 14, color: AppColors.primaryBlue),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: FontAwesomeIcons.arrowUp,
                label: t.t('upload'),
                value: Fmt.bytes(vpn.up),
                color: AppColors.successGreen,
              ).fadeInUp(index: 2),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: StatTile(
                icon: FontAwesomeIcons.arrowDown,
                label: t.t('download'),
                value: Fmt.bytes(vpn.down),
                color: AppColors.deepBlue,
              ).fadeInUp(index: 3),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: FontAwesomeIcons.bolt,
                label: t.t('connections'),
                value: '${vpn.connections}',
                color: AppColors.warningAmber,
              ).fadeInUp(index: 4),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: StatTile(
                icon: FontAwesomeIcons.stopwatch,
                label: t.t('uptime'),
                value: vpn.startedAt > 0 && running ? Fmt.duration(DateTime.now().millisecondsSinceEpoch - vpn.startedAt) : '-',
              ).fadeInUp(index: 5),
            ),
          ],
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.cardGap),
          AnimatedCard(
            index: 5,
            onTap: () => Navigator.of(context).push(
              SlideFromRightRoute<void>(builder: (_) => BreakpointScreen(item: pending.first)),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.pause, size: 18, color: AppColors.warningAmber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${t.t('pending_bp')}: ${pending.length}', style: AppText.bodyMedium(p)),
                ),
                const FaIcon(FontAwesomeIcons.arrowRight, size: 14, color: AppColors.primaryBlue),
              ],
            ),
          ),
        ],
        SectionHeader(title: t.t('quick_actions')),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: FontAwesomeIcons.list,
                label: t.t('nav_traffic'),
                onTap: onOpenTraffic,
                index: 5,
              ),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: _QuickAction(
                icon: FontAwesomeIcons.sliders,
                label: t.t('open_rules'),
                onTap: onOpenRules,
                index: 6,
              ),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: _QuickAction(
                icon: FontAwesomeIcons.globe,
                label: t.t('nav_monitor'),
                index: 7,
                onTap: () => Navigator.of(context).push(
                  SlideFromRightRoute<void>(builder: (_) => const MonitorScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: _QuickAction(
                icon: FontAwesomeIcons.certificate,
                label: t.t('open_certificate'),
                index: 7,
                onTap: () => Navigator.of(context).push(
                  SlideFromRightRoute<void>(builder: (_) => const CertificateScreen()),
                ),
              ),
            ),
          ],
        ),
        SectionHeader(
          title: t.t('recent'),
          trailing: TextButton(onPressed: onOpenTraffic, child: Text(t.t('see_all'))),
        ),
        if (recent.isEmpty)
          AnimatedCard(
            index: 6,
            child: Text(t.t('empty_traffic_body'), style: AppText.caption(p).copyWith(fontSize: 13)),
          )
        else
          for (var i = 0; i < recent.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: RequestTile(
                item: recent[i],
                onTap: () => Navigator.of(context).push(
                  SlideFromRightRoute<void>(builder: (_) => TrafficDetailScreen(id: recent[i].id)),
                ),
              ).fadeInUp(index: i + 6),
            ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, required this.index});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedCard(
      index: index,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          FaIcon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(p).copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

SkyMood _moodFor(VpnStatus v) {
  if (v.isBusy) return SkyMood.brightening;
  if (v.isRunning) return v.paused ? SkyMood.dusk : SkyMood.clear;
  return SkyMood.overcast;
}

Color _pillColor(VpnStatus v) {
  if (v.phase == VpnPhase.error) return AppColors.errorRed;
  if (v.isRunning) return v.paused ? AppColors.warningAmber : AppColors.successGreen;
  if (v.isBusy) return AppColors.primaryBlue;
  return AppColors.textSecondary;
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color, required this.active});

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dot = Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          active
              ? dot.animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.45, end: 1, duration: 1100.ms)
              : dot,
          const SizedBox(width: 8),
          Text(label, style: AppText.bodyMedium(p).copyWith(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: p.brandStrong),
          const SizedBox(width: 6),
          Text(label, style: AppText.label(p).copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.locked, required this.strings, required this.onChanged});

  final String mode;
  final bool locked;
  final Strings strings;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget chip(String value, String label, IconData icon) {
      final selected = mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: locked || selected ? null : () => onChanged(value),
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: selected ? AppComponents.primaryGradient : null,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icon, size: 14, color: selected ? AppColors.cloudWhite : AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppText.bodyMedium(p).copyWith(
                    color: selected ? AppColors.cloudWhite : p.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: locked ? 0.7 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.control + 4),
            ),
            child: Row(
              children: [
                chip('vpn', strings.t('mode_vpn'), FontAwesomeIcons.shieldHalved),
                chip('proxy', strings.t('mode_proxy'), FontAwesomeIcons.globe),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              locked
                  ? strings.t('mode_locked')
                  : mode == 'proxy'
                      ? strings.t('mode_proxy_hint')
                      : strings.t('mode_vpn_hint'),
              style: AppText.label(p),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProxyCard extends ConsumerWidget {
  const _ProxyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final running = ref.watch(vpnProvider.select((v) => v.isRunning));
    final info = ref.watch(proxyInfoProvider);

    return AnimatedCard(
      index: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.globe, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Expanded(child: Text(t.t('proxy_title'), style: AppText.heading(p))),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.t('proxy_steps'), style: AppText.caption(p).copyWith(fontSize: 12.5)),
          const SizedBox(height: 10),
          info.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
            error: (e, _) => Text('$e', style: AppText.caption(p).copyWith(color: AppColors.errorRed)),
            data: (data) {
              final hosts = data.bindAll ? data.addresses : <String>['127.0.0.1'];
              if (hosts.isEmpty) {
                return Text(t.t('proxy_no_ip'), style: AppText.caption(p));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final host in hosts)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: '$host:${data.port}'));
                        messenger.showSnackBar(SnackBar(content: Text(t.t('copied')), duration: const Duration(seconds: 1)));
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text('$host:${data.port}', style: AppText.mono(p, size: 14))),
                            const FaIcon(FontAwesomeIcons.copy, size: 14, color: AppColors.primaryBlue),
                          ],
                        ),
                      ),
                    ),
                  if (data.bindAll && !data.authSet)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        t.t('proxy_open_warn'),
                        style: AppText.label(p).copyWith(color: AppColors.errorRed, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (data.authSet) Text(t.t('proxy_auth_on'), style: AppText.label(p)),
                  if (data.bindAll) Text(t.t('proxy_other'), style: AppText.label(p)),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(running ? t.t('proxy_limit') : t.t('proxy_off_note'), style: AppText.label(p)),
        ],
      ),
    );
  }
}
