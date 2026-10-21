import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/traffic.dart';
import '../providers/core_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_provider.dart';
import '../providers/vpn_provider.dart';
import '../services/export_service.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/request_tile.dart';
import 'traffic_detail_screen.dart';

class TrafficScreen extends ConsumerStatefulWidget {
  const TrafficScreen({super.key});

  @override
  ConsumerState<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends ConsumerState<TrafficScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    ref.read(trafficProvider.notifier).setFrozen(pos.pixels > 160);
    if (pos.pixels > pos.maxScrollExtent - 500) {
      ref.read(trafficProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final controller = ref.read(trafficProvider.notifier);
      final current = ref.read(trafficProvider).filter;
      controller.setFilter(current.copyWith(search: value.trim().isEmpty ? null : value.trim()));
    });
  }

  Future<String?> _pick(String title, List<MapEntry<String, String>> options, String? current) {
    final t = ref.read(stringsProvider);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
              children: [
                Text(title, style: AppText.title(p)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.t('all')),
                  trailing: current == null ? const FaIcon(FontAwesomeIcons.check, size: 14, color: AppColors.primaryBlue) : null,
                  onTap: () => Navigator.of(ctx).pop(''),
                ),
                for (final o in options)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: current == o.key ? const FaIcon(FontAwesomeIcons.check, size: 14, color: AppColors.primaryBlue) : null,
                    onTap: () => Navigator.of(ctx).pop(o.key),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyPick(String title, List<MapEntry<String, String>> options, String? current,
      void Function(String? value) apply) async {
    final result = await _pick(title, options, current);
    if (result == null) return;
    apply(result.isEmpty ? null : result);
  }

  Future<void> _itemMenu(TrafficSummary item) async {
    final t = ref.read(stringsProvider);
    final controller = ref.read(trafficProvider.notifier);
    final hasFilter = !ref.read(trafficProvider).filter.isEmpty;
    final adSettings = ref.read(settingsProvider).settings;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.copy, size: 16, color: AppColors.primaryBlue),
              title: Text(t.t('copy_url')),
              onTap: () => Navigator.of(ctx).pop('copy'),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.trash, size: 16, color: AppColors.errorRed),
              title: Text(t.t('del_item')),
              onTap: () => Navigator.of(ctx).pop('item'),
            ),
            if (item.blocked)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.circleCheck, size: 16, color: AppColors.successGreen),
                title: Text(t.t('allow_domain')),
                onTap: () => Navigator.of(ctx).pop('allow'),
              )
            else if (adSettings.adblockEnabled && !item.tunnel && item.method != 'TLS')
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.ban, size: 16, color: AppColors.warningAmber),
                title: Text(t.t('block_domain')),
                onTap: () => Navigator.of(ctx).pop('block'),
              ),
            if (hasFilter)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.filter, size: 16, color: AppColors.errorRed),
                title: Text(t.t('del_filtered')),
                onTap: () => Navigator.of(ctx).pop('filtered'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: '${item.scheme}://${item.host}${item.path}'));
      messenger.showSnackBar(SnackBar(content: Text(t.t('copied')), duration: const Duration(seconds: 1)));
    } else if (action == 'item') {
      await controller.deleteItem(item.id);
      messenger.showSnackBar(SnackBar(content: Text(t.t('del_done')), duration: const Duration(seconds: 1)));
    } else if (action == 'allow') {
      final list = adSettings.adblockAllow.trim();
      await ref.read(settingsProvider.notifier).update({'adblockAllow': list.isEmpty ? item.host : '$list\n${item.host}'});
      messenger.showSnackBar(SnackBar(content: Text(t.t('target_saved')), duration: const Duration(seconds: 1)));
    } else if (action == 'block') {
      final list = adSettings.adblockCustom.trim();
      await ref.read(settingsProvider.notifier).update({'adblockCustom': list.isEmpty ? item.host : '$list\n${item.host}'});
      messenger.showSnackBar(SnackBar(content: Text(t.t('target_saved')), duration: const Duration(seconds: 1)));
    } else if (action == 'filtered') {
      await controller.deleteFiltered();
      messenger.showSnackBar(SnackBar(content: Text(t.t('del_done')), duration: const Duration(seconds: 1)));
    }
  }

  Future<void> _confirmClear() async {
    final t = ref.read(stringsProvider);
    final ok = await showScaleDialog<bool>(
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
                  Text(t.t('clear_all'), style: AppText.title(p)),
                  const SizedBox(height: 8),
                  Text(t.t('clear_confirm'), style: AppText.body(p)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.t('cancel'))),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(t.t('delete'), style: const TextStyle(color: AppColors.errorRed)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok == true) {
      await ref.read(trafficProvider.notifier).clearAll();
    }
  }

  Future<void> _export(ExportFormat format) async {
    final filter = ref.read(trafficProvider).filter;
    await ref.read(exportServiceProvider).exportAndShare(format, filter: filter);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final state = ref.watch(trafficProvider);
    final controller = ref.read(trafficProvider.notifier);
    final facets = ref.watch(facetsProvider);
    final p = context.palette;
    final filter = state.filter;
    final paused = ref.watch(vpnProvider.select((v) => v.paused));
    final vpnController = ref.read(vpnProvider.notifier);

    final apps = facets.valueOrNull?.apps ?? const [];
    final hosts = facets.valueOrNull?.hosts ?? const [];
    String? appLabel;
    for (final a in apps) {
      if (a.appPackage == filter.app) appLabel = a.appName;
    }

    Widget body;
    if (state.loading) {
      body = const ShimmerList();
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorState(message: state.error!, retryLabel: t.t('retry'), onRetry: controller.load);
    } else if (state.items.isEmpty) {
      body = RefreshIndicator(
        color: AppColors.primaryBlue,
        backgroundColor: p.surface,
        onRefresh: controller.load,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: EmptyState(
                  icon: FontAwesomeIcons.globe,
                  title: t.t('empty_traffic_title'),
                  body: t.t('empty_traffic_body'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.primaryBlue,
        backgroundColor: p.surface,
        displacement: 24,
        onRefresh: controller.load,
        child: ListView.separated(
          controller: _scroll,
          cacheExtent: 800,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, AppSpacing.page),
          itemCount: state.items.length + (state.loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final item = state.items[index];
            final tile = RequestTile(
              onLongPress: () => _itemMenu(item),
              item: item,
              onTap: () => Navigator.of(context).push(
                SlideFromRightRoute<void>(builder: (_) => TrafficDetailScreen(id: item.id)),
              ),
            );
            return index < 10 ? tile.fadeInUp(index: index) : tile;
          },
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.tight + 4, AppSpacing.page, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  style: AppText.body(p),
                  decoration: AppComponents.input(
                    p,
                    hint: t.t('search_hint'),
                    prefix: const Padding(
                      padding: EdgeInsets.all(14),
                      child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14, color: AppColors.primaryBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: paused ? t.t('rec_resume') : t.t('rec_pause'),
                onPressed: () => vpnController.setPaused(!paused),
                icon: FaIcon(
                  paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
                  size: 18,
                  color: paused ? AppColors.warningAmber : AppColors.primaryBlue,
                ),
              ),
              PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.fileArrowDown, size: 18, color: AppColors.primaryBlue),
                tooltip: t.t('export'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                onSelected: (v) {
                  if (v == 'har') _export(ExportFormat.har);
                  if (v == 'curl') _export(ExportFormat.curl);
                  if (v == 'raw') _export(ExportFormat.raw);
                  if (v == 'clear') _confirmClear();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'har', child: Text('${t.t('export')} ${t.t('export_har')}')),
                  PopupMenuItem(value: 'curl', child: Text('${t.t('export')} ${t.t('export_curl')}')),
                  PopupMenuItem(value: 'raw', child: Text('${t.t('export')} ${t.t('export_raw')}')),
                  PopupMenuItem(value: 'clear', child: Text(t.t('clear_all'))),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
            children: [
              SkyFilterChip(
                label: appLabel ?? t.t('filter_app'),
                icon: FontAwesomeIcons.mobileScreen,
                selected: filter.app != null,
                onClear: () => controller.setFilter(filter.copyWith(app: null)),
                onTap: () => _applyPick(
                  t.t('filter_app'),
                  [for (final a in apps) MapEntry(a.appPackage, '${a.appName} (${a.requests})')],
                  filter.app,
                  (v) => controller.setFilter(filter.copyWith(app: v)),
                ),
              ),
              const SizedBox(width: 8),
              SkyFilterChip(
                label: filter.method ?? t.t('filter_method'),
                icon: FontAwesomeIcons.paperPlane,
                selected: filter.method != null,
                onClear: () => controller.setFilter(filter.copyWith(method: null)),
                onTap: () => _applyPick(
                  t.t('filter_method'),
                  [for (final m in const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TUNNEL']) MapEntry(m, m)],
                  filter.method,
                  (v) => controller.setFilter(filter.copyWith(method: v)),
                ),
              ),
              const SizedBox(width: 8),
              SkyFilterChip(
                label: filter.status ?? t.t('filter_status'),
                icon: FontAwesomeIcons.circleCheck,
                selected: filter.status != null,
                onClear: () => controller.setFilter(filter.copyWith(status: null)),
                onTap: () => _applyPick(
                  t.t('filter_status'),
                  [for (final s in const ['2xx', '3xx', '4xx', '5xx', 'error']) MapEntry(s, s)],
                  filter.status,
                  (v) => controller.setFilter(filter.copyWith(status: v)),
                ),
              ),
              const SizedBox(width: 8),
              SkyFilterChip(
                label: filter.domain ?? t.t('filter_domain'),
                icon: FontAwesomeIcons.globe,
                selected: filter.domain != null,
                onClear: () => controller.setFilter(filter.copyWith(domain: null)),
                onTap: () => _applyPick(
                  t.t('filter_domain'),
                  [for (final h in hosts) MapEntry(h.host, '${h.host} (${h.requests})')],
                  filter.domain,
                  (v) => controller.setFilter(filter.copyWith(domain: v)),
                ),
              ),
              const SizedBox(width: 8),
              SkyFilterChip(
                label: filter.contentType ?? t.t('filter_type'),
                icon: FontAwesomeIcons.code,
                selected: filter.contentType != null,
                onClear: () => controller.setFilter(filter.copyWith(contentType: null)),
                onTap: () => _applyPick(
                  t.t('filter_type'),
                  [for (final c in const ['json', 'html', 'xml', 'javascript', 'text', 'image', 'form']) MapEntry(c, c)],
                  filter.contentType,
                  (v) => controller.setFilter(filter.copyWith(contentType: v)),
                ),
              ),
              const SizedBox(width: 8),
              SkyFilterChip(
                label: t.t('filter_modified'),
                icon: FontAwesomeIcons.wandMagic,
                selected: filter.onlyModified,
                onTap: () => controller.setFilter(filter.copyWith(onlyModified: !filter.onlyModified)),
              ),
              const SizedBox(width: 8),
              SkyFilterChip(
                label: t.t('filter_bodies'),
                icon: FontAwesomeIcons.fileLines,
                selected: filter.searchBodies,
                onTap: () => controller.setFilter(filter.copyWith(searchBodies: !filter.searchBodies)),
              ),
            ],
          ),
        ),
        if (paused)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.pause, size: 12, color: AppColors.warningAmber),
                const SizedBox(width: 8),
                Expanded(child: Text(t.t('rec_paused_banner'), style: AppText.label(p))),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              AnimatedSwitcher(duration: AppMotion.fast, child: KeyedSubtree(key: ValueKey(state.loading), child: body)),
              if (state.held > 0)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        onTap: () => _scroll.animateTo(0, duration: AppMotion.base, curve: AppMotion.curve),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FaIcon(FontAwesomeIcons.arrowUp, size: 12, color: AppColors.cloudWhite),
                              const SizedBox(width: 8),
                              Text(
                                '${state.held} ${t.t('new_requests')}',
                                style: AppText.button().copyWith(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
