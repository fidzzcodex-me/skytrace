import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_info.dart';
import '../providers/settings_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/sky_button.dart';

class TargetAppsScreen extends ConsumerStatefulWidget {
  const TargetAppsScreen({super.key});

  @override
  ConsumerState<TargetAppsScreen> createState() => _TargetAppsScreenState();
}

class _TargetAppsScreenState extends ConsumerState<TargetAppsScreen> {
  late final Set<String> _selected = ref.read(settingsProvider).settings.targetApps.toSet();
  final TextEditingController _search = TextEditingController();
  bool _includeSystem = false;
  bool _saving = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InstalledApp> _visible(List<InstalledApp> apps) {
    final q = _query.trim().toLowerCase();
    final filtered = apps.where((a) {
      if (q.isEmpty) return true;
      return a.label.toLowerCase().contains(q) || a.package.toLowerCase().contains(q);
    }).toList();
    final chosen = filtered.where((a) => _selected.contains(a.package)).toList();
    final rest = filtered.where((a) => !_selected.contains(a.package)).toList();
    return [...chosen, ...rest];
  }

  Future<void> _save() async {
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final vpn = ref.read(vpnProvider.notifier);
    final wasRunning = ref.read(vpnProvider).isRunning;
    setState(() => _saving = true);
    await ref.read(settingsProvider.notifier).update({'targetApps': _selected.toList()});
    if (wasRunning) {
      await vpn.stop();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await vpn.start();
    }
    messenger.showSnackBar(SnackBar(content: Text(t.t('target_saved')), duration: const Duration(seconds: 1)));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final async = ref.watch(installedAppsProvider(_includeSystem));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('target_title')),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
            child: Text(t.t('target_clear')),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.inner, AppSpacing.page, 0),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body(p),
              decoration: AppComponents.input(
                p,
                hint: t.t('target_hint'),
                prefix: const Padding(
                  padding: EdgeInsets.all(14),
                  child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14, color: AppColors.primaryBlue),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                Expanded(child: Text(t.t('target_system'), style: AppText.caption(p))),
                Switch(value: _includeSystem, onChanged: (v) => setState(() => _includeSystem = v)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.tight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selected.isEmpty ? t.t('target_all') : '${_selected.length} ${t.t('target_count')}',
                style: AppText.bodyMedium(p).copyWith(color: p.brandStrong),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const ShimmerList(count: 8),
              error: (e, _) => ErrorState(
                message: '$e',
                retryLabel: t.t('retry'),
                onRetry: () => ref.invalidate(installedAppsProvider(_includeSystem)),
              ),
              data: (apps) {
                final list = _visible(apps);
                if (list.isEmpty) {
                  return EmptyState(icon: FontAwesomeIcons.mobileScreen, title: t.t('target_empty'), body: '');
                }
                return ListView.builder(
                  cacheExtent: 800,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final app = list[i];
                    final on = _selected.contains(app.package);
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      onTap: () => setState(() {
                        if (on) {
                          _selected.remove(app.package);
                        } else {
                          _selected.add(app.package);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            AppIcon(package: app.package, size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium(p)),
                                  Text(app.package, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(p)),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: on,
                              activeColor: AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(app.package);
                                } else {
                                  _selected.remove(app.package);
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.t('target_note'), style: AppText.label(p), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  SkyButton(label: t.t('save'), expand: true, loading: _saving, onPressed: _save),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
