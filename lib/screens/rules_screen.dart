import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/rule.dart';
import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import '../utils/strings.dart';
import '../widgets/animated_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/method_badge.dart';
import '../widgets/section_header.dart';
import 'breakpoint_screen.dart';
import 'rule_editor_sheet.dart';

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  IconData _actionIcon(RuleAction a) {
    switch (a) {
      case RuleAction.redirect:
        return FontAwesomeIcons.forward;
      case RuleAction.modifyHeader:
        return FontAwesomeIcons.code;
      case RuleAction.replaceBody:
        return FontAwesomeIcons.pen;
      case RuleAction.mock:
        return FontAwesomeIcons.robot;
      case RuleAction.delay:
        return FontAwesomeIcons.hourglass;
    }
  }

  String _actionLabel(RuleAction a, Strings t) {
    switch (a) {
      case RuleAction.redirect:
        return t.t('action_redirect');
      case RuleAction.modifyHeader:
        return t.t('action_header');
      case RuleAction.replaceBody:
        return t.t('action_body');
      case RuleAction.mock:
        return t.t('action_mock');
      case RuleAction.delay:
        return t.t('action_delay');
    }
  }

  Future<bool> _confirmDelete(String name) async {
    final t = ref.read(stringsProvider);
    final result = await showScaleDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return Center(
          child: Material(
            color: p.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(AppSpacing.page + 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('delete'), style: AppText.title(p)),
                  const SizedBox(height: 8),
                  Text(name, style: AppText.body(p)),
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
    return result == true;
  }

  Future<void> _addNew() async {
    if (_tabs.index == 0) {
      final rule = await showRuleEditor(context, const RewriteRule());
      if (rule != null) await ref.read(rulesProvider.notifier).saveRule(rule);
    } else {
      final bp = await showBreakpointEditor(context, const BreakpointRule());
      if (bp != null) await ref.read(rulesProvider.notifier).saveBreakpoint(bp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final state = ref.watch(rulesProvider);
    final controller = ref.read(rulesProvider.notifier);
    final p = context.palette;

    Widget rewriteTab() {
      if (state.rules.isEmpty) {
        return EmptyState(
          icon: FontAwesomeIcons.wandMagic,
          title: t.t('empty_rules_title'),
          body: t.t('empty_rules_body'),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.page),
        cacheExtent: 600,
        itemCount: state.rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
        itemBuilder: (context, i) {
          final r = state.rules[i];
          return Dismissible(
            key: ValueKey('rule-${r.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(r.name.isEmpty ? r.urlPattern : r.name),
            onDismissed: (_) => controller.deleteRule(r.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const FaIcon(FontAwesomeIcons.trash, color: AppColors.errorRed, size: 18),
            ),
            child: AnimatedCard(
              index: i,
              onTap: () async {
                final edited = await showRuleEditor(context, r);
                if (edited != null) await controller.saveRule(edited);
              },
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: FaIcon(_actionIcon(r.action), size: 16, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name.isEmpty ? _actionLabel(r.action, t) : r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.heading(p).copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          Fmt.ellipsize(r.urlPattern, 44),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.mono(p, size: 11.5).copyWith(color: p.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (r.method != '*') ...[MethodBadge(method: r.method, compact: true), const SizedBox(width: 6)],
                            Text(
                              '${_actionLabel(r.action, t)} | ${r.phase == RulePhase.request ? t.t('phase_request') : t.t('phase_response')}',
                              style: AppText.label(p),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(value: r.enabled, onChanged: (v) => controller.toggleRule(r, v)),
                ],
              ),
            ),
          );
        },
      );
    }

    Widget breakpointTab() {
      final children = <Widget>[];
      if (state.pending.isNotEmpty) {
        children.add(SectionHeader(title: '${t.t('bp_waiting')} (${state.pending.length})'));
        for (var i = 0; i < state.pending.length; i++) {
          final item = state.pending[i];
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: AnimatedCard(
                index: i,
                onTap: () => Navigator.of(context).push(
                  SlideFromRightRoute<void>(builder: (_) => BreakpointScreen(item: item)),
                ),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.pause, size: 18, color: AppColors.warningAmber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.isRequest ? t.t('phase_request') : t.t('phase_response')}  ${item.method}',
                            style: AppText.bodyMedium(p),
                          ),
                          Text(
                            Fmt.ellipsize(item.url, 60),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(p),
                          ),
                        ],
                      ),
                    ),
                    const FaIcon(FontAwesomeIcons.arrowRight, size: 14, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
          );
        }
      }
      if (state.breakpoints.isEmpty && state.pending.isEmpty) {
        return EmptyState(
          icon: FontAwesomeIcons.pause,
          title: t.t('empty_bp_title'),
          body: t.t('empty_bp_body'),
        );
      }
      for (var i = 0; i < state.breakpoints.length; i++) {
        final b = state.breakpoints[i];
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
            child: Dismissible(
              key: ValueKey('bp-${b.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(b.name.isEmpty ? b.urlPattern : b.name),
              onDismissed: (_) => controller.deleteBreakpoint(b.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const FaIcon(FontAwesomeIcons.trash, color: AppColors.errorRed, size: 18),
              ),
              child: AnimatedCard(
                index: i + state.pending.length,
                onTap: () async {
                  final edited = await showBreakpointEditor(context, b);
                  if (edited != null) await controller.saveBreakpoint(edited);
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const FaIcon(FontAwesomeIcons.pause, size: 16, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name.isEmpty ? b.urlPattern : b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.heading(p).copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Fmt.ellipsize(b.urlPattern, 44),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.mono(p, size: 11.5).copyWith(color: p.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (b.onRequest) t.t('phase_request'),
                              if (b.onResponse) t.t('phase_response'),
                            ].join(' + '),
                            style: AppText.label(p),
                          ),
                        ],
                      ),
                    ),
                    Switch(value: b.enabled, onChanged: (v) => controller.toggleBreakpoint(b, v)),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        cacheExtent: 600,
        children: children,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _addNew,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.cloudWhite,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        child: const FaIcon(FontAwesomeIcons.plus, size: 18),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: p.textSecondary,
            indicatorColor: AppColors.primaryBlue,
            tabs: [
              Tab(text: t.t('rules_rewrite')),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.t('rules_breakpoint')),
                    if (state.pending.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(8)),
                        child: Text('${state.pending.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [rewriteTab(), breakpointTab()],
            ),
          ),
        ],
      ),
    );
  }
}
