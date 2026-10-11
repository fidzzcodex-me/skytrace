import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_info.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import '../utils/strings.dart';
import '../widgets/animated_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_tile.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) ref.invalidate(statsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final async = ref.watch(statsProvider);
    final p = context.palette;

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      backgroundColor: p.surface,
      onRefresh: () async {
        ref.invalidate(statsProvider);
        await ref.read(statsProvider.future);
      },
      child: async.when(
        loading: () => const ShimmerList(count: 4),
        error: (e, _) => ErrorState(message: '$e', retryLabel: t.t('retry'), onRetry: () => ref.invalidate(statsProvider)),
        data: (s) {
          if (s.requests == 0) {
            return LayoutBuilder(
              builder: (context, c) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: c.maxHeight,
                    child: EmptyState(icon: FontAwesomeIcons.chartPie, title: t.t('stats_empty'), body: t.t('empty_traffic_body')),
                  ),
                ],
              ),
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.page),
            cacheExtent: 800,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(icon: FontAwesomeIcons.paperPlane, label: t.t('stats_total'), value: '${s.requests}').fadeInUp(),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: StatTile(
                      icon: FontAwesomeIcons.gauge,
                      label: t.t('stats_avg'),
                      value: Fmt.duration(s.avgMs),
                      color: AppColors.warningAmber,
                    ).fadeInUp(index: 1),
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
                      value: Fmt.bytes(s.up),
                      color: AppColors.successGreen,
                    ).fadeInUp(index: 2),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: StatTile(
                      icon: FontAwesomeIcons.arrowDown,
                      label: t.t('download'),
                      value: Fmt.bytes(s.down),
                      color: AppColors.deepBlue,
                    ).fadeInUp(index: 3),
                  ),
                ],
              ),
              SectionHeader(title: t.t('stats_per_min')),
              AnimatedCard(index: 4, child: SizedBox(height: 170, child: _SeriesChart(points: s.series))),
              SectionHeader(title: t.t('stats_status')),
              AnimatedCard(index: 5, child: _StatusChart(buckets: s.statusBuckets)),
              SectionHeader(title: t.t('stats_time')),
              AnimatedCard(index: 6, child: SizedBox(height: 170, child: _TimeChart(buckets: s.timeBuckets))),
              SectionHeader(title: t.t('stats_apps')),
              AnimatedCard(index: 7, child: _AppList(apps: s.perApp)),
              SectionHeader(title: t.t('stats_domains')),
              AnimatedCard(index: 8, child: _DomainList(domains: s.topDomains, strings: t)),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({required this.points});

  final List<SeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (points.isEmpty) return const SizedBox.shrink();
    final nowMinute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final byMinute = {for (final pt in points) pt.minute: pt.count};
    final spots = <FlSpot>[];
    for (var i = 0; i < 60; i++) {
      final minute = nowMinute - 59 + i;
      spots.add(FlSpot(i.toDouble(), (byMinute[minute] ?? 0).toDouble()));
    }
    final maxY = spots.fold<double>(1, (a, b) => b.y > a ? b.y : a);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: p.surfaceAlt, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, meta) =>
                  Text(v.toInt().toString(), style: AppText.label(p).copyWith(fontSize: 10)),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: AppColors.primaryBlue,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.accentBlue.withOpacity(0.2)),
          ),
        ],
      ),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
    );
  }
}

class _StatusChart extends StatelessWidget {
  const _StatusChart({required this.buckets});

  final List<int> buckets;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labels = ['1xx', '2xx', '3xx', '4xx', '5xx', 'ERR'];
    final colors = [
      AppColors.textMuted,
      AppColors.successGreen,
      AppColors.deepBlue,
      AppColors.warningAmber,
      AppColors.errorRed,
      AppColors.textMuted,
    ];
    final total = buckets.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i] == 0) continue;
      sections.add(PieChartSectionData(
        value: buckets[i].toDouble(),
        color: colors[i],
        radius: 26,
        showTitle: false,
      ));
    }
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(sections: sections, centerSpaceRadius: 34, sectionsSpace: 2),
            duration: AppMotion.slow,
            curve: AppMotion.curve,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < buckets.length; i++)
                if (buckets[i] > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(labels[i], style: AppText.bodyMedium(p)),
                        const Spacer(),
                        Text(
                          '${buckets[i]}  (${total == 0 ? 0 : (buckets[i] * 100 / total).round()}%)',
                          style: AppText.caption(p),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeChart extends StatelessWidget {
  const _TimeChart({required this.buckets});

  final List<int> buckets;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labels = ['<100', '<300', '<1s', '<3s', '3s+'];
    final maxY = buckets.fold<int>(1, (a, b) => b > a ? b : a).toDouble();
    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: p.surfaceAlt, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: AppText.label(p).copyWith(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i], style: AppText.label(p).copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].toDouble(),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: AppComponents.primaryGradient,
                ),
              ],
            ),
        ],
      ),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.apps});

  final List<AppStat> apps;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxReq = apps.fold<int>(1, (a, b) => b.requests > a ? b.requests : a);
    return Column(
      children: [
        for (final a in apps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                AppIcon(package: a.appPackage, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(a.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium(p)),
                          ),
                          Text('${a.requests}', style: AppText.heading(p).copyWith(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: a.requests / maxReq,
                          minHeight: 6,
                          backgroundColor: p.surfaceAlt,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.bytes(a.up)} up | ${Fmt.bytes(a.down)} down | ${Fmt.duration(a.avgMs)}',
                        style: AppText.label(p),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DomainList extends StatelessWidget {
  const _DomainList({required this.domains, required this.strings});

  final List<DomainStat> domains;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        for (var i = 0; i < domains.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: AppText.label(p))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(domains[i].host, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium(p)),
                      Text('${Fmt.bytes(domains[i].down)} | ${Fmt.duration(domains[i].avgMs)}', style: AppText.label(p)),
                    ],
                  ),
                ),
                Text('${domains[i].requests}', style: AppText.heading(p).copyWith(fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }
}
