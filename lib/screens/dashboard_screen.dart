import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_info.dart';
import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import '../utils/strings.dart';
import '../widgets/animated_card.dart';
import '../widgets/request_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_tile.dart';
import '../widgets/trace_arc.dart';
import 'breakpoint_screen.dart';
import 'certificate_screen.dart';
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
    final running = vpn.isRunning;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      cacheExtent: 600,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card + 4),
            gradient: AppComponents.skyBackground(p),
            boxShadow: AppComponents.cardShadow(p),
            border: Border.all(color: p.surfaceAlt),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned(right: -50, top: -30, child: TraceArc(size: 240, opacity: 0.3)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page + 4),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: toggle,
                      child: AnimatedContainer(
                        duration: AppMotion.base,
                        curve: AppMotion.curve,
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: running
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.accentBlue, AppColors.primaryBlue],
                                )
                              : null,
                          color: running ? null : p.surface,
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: running ? 0 : 0.4), width: 2),
                          boxShadow: AppComponents.softShadow(p),
                        ),
                        alignment: Alignment.center,
                        child: vpn.isBusy
                            ? const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryBlue),
                              )
                            : FaIcon(
                                FontAwesomeIcons.powerOff,
                                size: 40,
                                color: running ? AppColors.cloudWhite : AppColors.primaryBlue,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Text(
                        _phaseText(vpn.phase, t),
                        key: ValueKey(vpn.phase),
                        style: AppText.heading(p),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vpn.phase == VpnPhase.error && vpn.error.isNotEmpty
                          ? vpn.error
                          : running
                              ? '${vpn.connections} ${t.t('connections').toLowerCase()}'
                              : t.t('vpn_start'),
                      style: AppText.caption(p),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).fadeInUp(),
        const SizedBox(height: AppSpacing.cardGap),
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
              child: StatTile(icon: FontAwesomeIcons.paperPlane, label: t.t('requests'), value: '${vpn.requests}')
                  .fadeInUp(index: 1),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: StatTile(
                icon: FontAwesomeIcons.bolt,
                label: t.t('connections'),
                value: '${vpn.connections}',
                color: AppColors.warningAmber,
              ).fadeInUp(index: 2),
            ),
          ],
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
              ).fadeInUp(index: 3),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: StatTile(
                icon: FontAwesomeIcons.arrowDown,
                label: t.t('download'),
                value: Fmt.bytes(vpn.down),
                color: AppColors.deepBlue,
              ).fadeInUp(index: 4),
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
