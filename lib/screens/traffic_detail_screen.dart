import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/request.dart';
import '../models/response.dart';
import '../models/traffic.dart';
import '../providers/core_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_provider.dart';
import '../services/export_service.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import '../utils/strings.dart';
import '../widgets/app_icon.dart';
import '../widgets/body_viewer.dart';
import '../widgets/code_viewer.dart';
import '../widgets/empty_state.dart';
import '../widgets/header_editor.dart';
import '../widgets/header_list.dart';
import '../widgets/method_badge.dart';
import '../widgets/section_header.dart';
import '../widgets/sky_button.dart';
import '../widgets/status_badge.dart';

class TrafficDetailScreen extends ConsumerStatefulWidget {
  const TrafficDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<TrafficDetailScreen> createState() => _TrafficDetailScreenState();
}

class _TrafficDetailScreenState extends ConsumerState<TrafficDetailScreen> {
  StreamSubscription? _sub;
  Timer? _debounce;
  bool _replaying = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(apiProvider).events.listen((event) {
      if (event.type == 'traffic_update' && (event.data['id'] as num?)?.toInt() == widget.id) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 200), () {
          if (mounted) ref.invalidate(trafficDetailProvider(widget.id));
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _replay(TrafficDetail d) async {
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _replaying = true);
    try {
      final newId = await ref.read(trafficRepositoryProvider).replay(d.id);
      if (!mounted) return;
      if (newId > 0) {
        navigator.push(SlideFromRightRoute<void>(builder: (_) => TrafficDetailScreen(id: newId)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${t.t('error_generic')}: $e')));
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }

  Future<void> _editAndReplay(TrafficDetail d) async {
    final override = await showModalBottomSheet<ReplayOverride>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReplaySheet(detail: d),
    );
    if (override == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final t = ref.read(stringsProvider);
    setState(() => _replaying = true);
    try {
      final newId = await ref.read(trafficRepositoryProvider).replay(d.id, override: override);
      if (!mounted) return;
      if (newId > 0) {
        navigator.push(SlideFromRightRoute<void>(builder: (_) => TrafficDetailScreen(id: newId)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${t.t('error_generic')}: $e')));
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }

  Future<void> _copy(String text) async {
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(t.t('copied')), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final async = ref.watch(trafficDetailProvider(widget.id));
    final p = context.palette;

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: '$e',
          retryLabel: t.t('retry'),
          onRetry: () => ref.invalidate(trafficDetailProvider(widget.id)),
        ),
      ),
      data: (d) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: FontAwesomeIcons.circleExclamation,
              title: t.t('error_generic'),
              body: '#${widget.id}',
            ),
          );
        }
        final canReplay = !d.tunnel && !d.isWebSocket && d.method != 'TLS';
        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(d.host, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                if (canReplay)
                  IconButton(
                    tooltip: t.t('replay'),
                    onPressed: _replaying ? null : () => _replay(d),
                    icon: _replaying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const FaIcon(FontAwesomeIcons.rotate, size: 18),
                  ),
                PopupMenuButton<String>(
                  icon: const FaIcon(FontAwesomeIcons.share, size: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                  onSelected: (v) async {
                    final export = ref.read(exportServiceProvider);
                    switch (v) {
                      case 'edit':
                        await _editAndReplay(d);
                      case 'curl':
                        await export.copyCurl(d.id);
                        if (mounted) _copiedToast(t);
                      case 'url':
                        await _copy(d.url);
                      case 'har':
                        await export.exportAndShare(ExportFormat.har, ids: [d.id]);
                      case 'raw':
                        await export.exportAndShare(ExportFormat.raw, ids: [d.id]);
                      case 'curlfile':
                        await export.exportAndShare(ExportFormat.curl, ids: [d.id]);
                    }
                  },
                  itemBuilder: (_) => [
                    if (canReplay) PopupMenuItem(value: 'edit', child: Text(t.t('replay_edit'))),
                    PopupMenuItem(value: 'curl', child: Text(t.t('copy_curl'))),
                    PopupMenuItem(value: 'url', child: Text(t.t('copy_url'))),
                    PopupMenuItem(value: 'har', child: Text('${t.t('export')} ${t.t('export_har')}')),
                    PopupMenuItem(value: 'curlfile', child: Text('${t.t('export')} ${t.t('export_curl')}')),
                    PopupMenuItem(value: 'raw', child: Text('${t.t('export')} ${t.t('export_raw')}')),
                  ],
                ),
              ],
              bottom: TabBar(
                labelStyle: AppText.bodyMedium(p).copyWith(fontSize: 12.5),
                unselectedLabelStyle: AppText.body(p).copyWith(fontSize: 12.5),
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: p.textSecondary,
                indicatorColor: AppColors.primaryBlue,
                tabs: [
                  Tab(text: t.t('tab_overview')),
                  Tab(text: t.t('tab_request')),
                  Tab(text: t.t('tab_response')),
                  Tab(text: t.t('tab_timing')),
                  Tab(text: t.t('tab_raw')),
                ],
              ),
            ),
            body: Column(
              children: [
                _SummaryHeader(detail: d, onCopyUrl: () => _copy(d.url)),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(detail: d, strings: t),
                      _MessageTab(
                        headers: d.requestHeaders,
                        body: d.request,
                        startLine: '${d.method} ${d.path} ${d.httpVersion}',
                        strings: t,
                      ),
                      _MessageTab(
                        headers: d.responseHeaders,
                        body: d.response,
                        startLine: '${d.httpVersion} ${d.statusCode} ${d.statusMessage}',
                        strings: t,
                      ),
                      _TimingTab(timings: d.timings, strings: t),
                      _RawTab(raw: d.raw, strings: t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copiedToast(Strings t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('copied')), duration: const Duration(seconds: 1)));
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.detail, required this.onCopyUrl});

  final TrafficDetail detail;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = detail;
    final failed = d.error != null;
    final label = failed
        ? 'ERR'
        : d.tunnel
            ? 'TUN'
            : d.statusCode == 0
                ? '...'
                : '${d.statusCode}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.inner, AppSpacing.page, AppSpacing.inner),
      decoration: BoxDecoration(color: p.surface, border: Border(bottom: BorderSide(color: p.surfaceAlt, width: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MethodBadge(method: d.method),
              const SizedBox(width: 8),
              StatusBadge(label: label, color: statusColorForCode(d.statusCode, failed: failed)),
              if (d.modified) ...[
                const SizedBox(width: 8),
                const FaIcon(FontAwesomeIcons.wandMagic, size: 12, color: AppColors.warningAmber),
              ],
              const Spacer(),
              Text(Fmt.duration(d.timings.total), style: AppText.label(p)),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onCopyUrl,
            child: Text(
              d.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(p, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail, required this.strings});

  final TrafficDetail detail;
  final Strings strings;

  Widget _row(BuildContext context, String label, Widget value) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text(label, style: AppText.caption(p))),
          Expanded(child: value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = detail;
    final t = strings;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.page),
          decoration: AppComponents.card(p),
          child: Column(
            children: [
              _row(
                context,
                t.t('field_app'),
                Row(
                  children: [
                    AppIcon(package: d.appPackage, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.appName, style: AppText.bodyMedium(p))),
                  ],
                ),
              ),
              _row(context, t.t('field_remote'), SelectableText(d.remoteIp.isEmpty ? '-' : '${d.remoteIp}:${d.port}', style: AppText.mono(p))),
              _row(context, t.t('field_time'), Text(Fmt.dateTime(d.timestamp), style: AppText.body(p))),
              _row(context, t.t('field_version'), Text(d.httpVersion.isEmpty ? '-' : d.httpVersion, style: AppText.body(p))),
              _row(context, '${t.t('tab_request')} ${t.t('field_size').toLowerCase()}', Text(Fmt.bytes(d.request.size), style: AppText.body(p))),
              _row(context, '${t.t('tab_response')} ${t.t('field_size').toLowerCase()}', Text(Fmt.bytes(d.response.size), style: AppText.body(p))),
              _row(context, t.t('timing_total'), Text(Fmt.duration(d.timings.total), style: AppText.body(p))),
              if (d.replayOf > 0) _row(context, t.t('replay'), Text('#${d.replayOf}', style: AppText.body(p))),
            ],
          ),
        ).fadeInUp(),
        if (d.error != null) ...[
          const SizedBox(height: AppSpacing.cardGap),
          Container(
            padding: const EdgeInsets.all(AppSpacing.page),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FaIcon(FontAwesomeIcons.circleExclamation, size: 16, color: AppColors.errorRed),
                const SizedBox(width: 10),
                Expanded(child: SelectableText(d.error!, style: AppText.body(p).copyWith(color: AppColors.errorRed))),
              ],
            ),
          ).fadeInUp(index: 1),
        ],
        if (d.tunnel) ...[
          const SizedBox(height: AppSpacing.cardGap),
          Text(t.t('tunnel_note'), style: AppText.caption(p)),
        ],
        if (d.isWebSocket) ...[
          const SizedBox(height: AppSpacing.cardGap),
          Text(t.t('ws_note'), style: AppText.caption(p)),
        ],
      ],
    );
  }
}

class _MessageTab extends StatelessWidget {
  const _MessageTab({required this.headers, required this.body, required this.startLine, required this.strings});

  final List<HeaderPair> headers;
  final BodyView body;
  final String startLine;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = strings;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      cacheExtent: 400,
      children: [
        Text(startLine, style: AppText.mono(p, size: 12.5).copyWith(fontWeight: FontWeight.w700)),
        SectionHeader(title: '${t.t('headers')} (${headers.length})'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.inner),
          decoration: AppComponents.card(p),
          child: headers.isEmpty
              ? Text('-', style: AppText.caption(p))
              : HeaderList(headers: headers, copiedLabel: t.t('copied')),
        ),
        SectionHeader(title: t.t('body')),
        BodyViewer(body: body, strings: t),
      ],
    );
  }
}

class _TimingTab extends StatelessWidget {
  const _TimingTab({required this.timings, required this.strings});

  final Timings timings;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = strings;
    final phases = <_Phase>[
      _Phase(t.t('timing_connect'), timings.connect, AppColors.deepBlue),
      _Phase(t.t('timing_tls'), timings.tls, AppColors.accentBlue),
      _Phase(t.t('timing_send'), timings.send, AppColors.primaryBlue),
      _Phase(t.t('timing_wait'), timings.wait, AppColors.warningAmber),
      _Phase(t.t('timing_receive'), timings.receive, AppColors.successGreen),
    ];
    final sum = phases.fold<int>(0, (a, b) => a + b.ms);
    final scale = sum <= 0 ? 1 : sum;
    var offset = 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.page),
          decoration: AppComponents.card(p),
          child: Column(
            children: [
              for (final ph in phases)
                Builder(builder: (context) {
                  final start = offset;
                  offset += ph.ms;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 74, child: Text(ph.label, style: AppText.caption(p))),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final left = c.maxWidth * start / scale;
                              final width = (c.maxWidth * ph.ms / scale).clamp(ph.ms > 0 ? 3.0 : 0.0, c.maxWidth);
                              return SizedBox(
                                height: 12,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: p.surfaceAlt.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    AnimatedPositioned(
                                      duration: AppMotion.slow,
                                      curve: AppMotion.curve,
                                      left: left,
                                      width: width,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        decoration: BoxDecoration(color: ph.color, borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(Fmt.duration(ph.ms), textAlign: TextAlign.right, style: AppText.label(p)),
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: Text(t.t('timing_total'), style: AppText.heading(p))),
                  Text(Fmt.duration(timings.total), style: AppText.heading(p)),
                ],
              ),
            ],
          ),
        ).fadeInUp(),
      ],
    );
  }
}

class _Phase {
  const _Phase(this.label, this.ms, this.color);

  final String label;
  final int ms;
  final Color color;
}

class _RawTab extends StatelessWidget {
  const _RawTab({required this.raw, required this.strings});

  final String raw;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        CodeViewer(text: raw, copyLabel: strings.t('copy'), copiedLabel: strings.t('copied')),
      ],
    );
  }
}

class _ReplaySheet extends StatefulWidget {
  const _ReplaySheet({required this.detail});

  final TrafficDetail detail;

  @override
  State<_ReplaySheet> createState() => _ReplaySheetState();
}

class _ReplaySheetState extends State<_ReplaySheet> {
  late final TextEditingController _url = TextEditingController(text: widget.detail.url);
  late final TextEditingController _body = TextEditingController(text: widget.detail.request.text);
  final GlobalKey<HeaderEditorState> _headers = GlobalKey<HeaderEditorState>();
  late String _method = widget.detail.method;

  @override
  void dispose() {
    _url.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Consumer(
      builder: (context, ref, _) {
        final t = ref.watch(stringsProvider);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
                children: [
                  Text(t.t('replay_edit'), style: AppText.title(p)),
                  const SizedBox(height: AppSpacing.page),
                  DropdownButtonFormField<String>(
                    value: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'].contains(_method) ? _method : null,
                    decoration: AppComponents.input(p, hint: t.t('edit_method')),
                    items: [
                      for (final m in const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'])
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setState(() => _method = v ?? _method),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _url,
                    style: AppText.mono(p),
                    decoration: AppComponents.input(p, hint: t.t('edit_url')),
                  ),
                  SectionHeader(title: t.t('edit_headers')),
                  HeaderEditor(key: _headers, initial: widget.detail.requestHeaders, addLabel: t.t('add_header')),
                  SectionHeader(title: t.t('body')),
                  TextField(
                    controller: _body,
                    minLines: 4,
                    maxLines: 12,
                    style: AppText.mono(p),
                    decoration: AppComponents.input(p),
                  ),
                  const SizedBox(height: AppSpacing.page),
                  SkyButton(
                    label: t.t('send'),
                    expand: true,
                    icon: const FaIcon(FontAwesomeIcons.paperPlane),
                    onPressed: () {
                      Navigator.of(context).pop(
                        ReplayOverride(
                          method: _method,
                          url: _url.text.trim(),
                          headers: _headers.currentState?.headers ?? widget.detail.requestHeaders,
                          bodyText: _body.text,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
