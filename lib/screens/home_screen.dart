import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/app_logo.dart';
import 'dashboard_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'traffic_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  void goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final pending = ref.watch(rulesProvider.select((s) => s.pending.length));

    final items = <_NavItem>[
      _NavItem(FontAwesomeIcons.house, t.t('nav_home')),
      _NavItem(FontAwesomeIcons.list, t.t('nav_traffic')),
      _NavItem(FontAwesomeIcons.sliders, t.t('nav_rules'), badge: pending),
      _NavItem(FontAwesomeIcons.chartLine, t.t('nav_stats')),
      _NavItem(FontAwesomeIcons.gear, t.t('nav_settings')),
    ];

    final titles = [
      'SkyTrace',
      t.t('nav_traffic'),
      t.t('nav_rules'),
      t.t('nav_stats'),
      t.t('nav_settings'),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.page,
        title: Row(
          children: [
            const AppLogo(variant: LogoVariant.mark, height: AppSpacing.logoAppBar),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Text(titles[_index], key: ValueKey(_index), style: AppText.heading(p).copyWith(color: p.brand)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: p.surfaceAlt),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onOpenTraffic: () => goTo(1), onOpenRules: () => goTo(2)),
          const TrafficScreen(),
          const RulesScreen(),
          const StatsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: AppSpacing.navHeight,
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.surfaceAlt, width: 0.5)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _NavButton(item: items[i], active: i == _index, onTap: () => goTo(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label, {this.badge = 0});

  final IconData icon;
  final String label;
  final int badge;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = active ? AppColors.primaryBlue : AppColors.primaryBlue.withOpacity(0.5);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: active ? p.surfaceAlt : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FaIcon(item.icon, size: 17, color: color),
                if (item.badge > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${item.badge}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            style: AppText.label(p).copyWith(
              fontSize: 10.5,
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
