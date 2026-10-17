import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/sky.dart';
import '../theme/text_styles.dart';
import '../widgets/app_logo.dart';
import '../widgets/sky_nav_bar.dart';
import '../widgets/update_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(overlayModeProvider)) ref.read(updateProvider.notifier).check();
    });
  }

  void goTo(int index) => setState(() => _index = index);

  Future<void> _togglePower() async {
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(vpnProvider.notifier).toggle();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error == 'vpn_denied' ? t.t('vpn_denied') : error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final pending = ref.watch(rulesProvider.select((s) => s.pending.length));
    final vpn = ref.watch(vpnProvider);

    ref.listen<UpdateState>(updateProvider, (previous, next) {
      final info = next.info;
      if (next.popupPending && info != null) {
        ref.read(updateProvider.notifier).consumePopup();
        showUpdateDialog(context, info, next.currentVersion);
      }
    });

    final items = <SkyNavItem>[
      SkyNavItem(icon: FontAwesomeIcons.house, label: t.t('nav_home')),
      SkyNavItem(icon: FontAwesomeIcons.list, label: t.t('nav_traffic')),
      SkyNavItem(icon: FontAwesomeIcons.sliders, label: t.t('nav_rules'), badge: pending),
      SkyNavItem(icon: FontAwesomeIcons.chartLine, label: t.t('nav_stats')),
    ];

    final titles = ['SkyTrace', t.t('nav_traffic'), t.t('nav_rules'), t.t('nav_stats')];

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
        actions: [
          IconButton(
            tooltip: t.t('settings_page'),
            onPressed: () => Navigator.of(context).push(
              SlideFromRightRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const FaIcon(FontAwesomeIcons.gear, size: 18),
          ),
          const SizedBox(width: 4),
        ],
        backgroundColor: p.gradientTop,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.5),
          child: HorizonLine(),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppSky.page(p)),
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onOpenTraffic: () => goTo(1), onOpenRules: () => goTo(2)),
            const TrafficScreen(),
            const RulesScreen(),
            const StatsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SkyNavBar(
        items: items,
        index: _index,
        onChanged: goTo,
        running: vpn.isRunning,
        busy: vpn.isBusy,
        onPower: _togglePower,
        powerLabel: vpn.isRunning ? t.t('vpn_stop') : t.t('vpn_start'),
      ),
    );
  }
}
