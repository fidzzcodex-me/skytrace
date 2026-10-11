import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/rule.dart';
import '../providers/rule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/header_editor.dart';
import '../widgets/method_badge.dart';
import '../widgets/section_header.dart';
import '../widgets/sky_button.dart';

class BreakpointScreen extends ConsumerStatefulWidget {
  const BreakpointScreen({super.key, required this.item});

  final PendingBreakpoint item;

  @override
  ConsumerState<BreakpointScreen> createState() => _BreakpointScreenState();
}

class _BreakpointScreenState extends ConsumerState<BreakpointScreen> {
  late final TextEditingController _method = TextEditingController(text: widget.item.method);
  late final TextEditingController _path = TextEditingController(text: _initialPath());
  late final TextEditingController _status = TextEditingController(text: widget.item.status.toString());
  late final TextEditingController _body = TextEditingController(text: widget.item.bodyText);
  final GlobalKey<HeaderEditorState> _headers = GlobalKey<HeaderEditorState>();
  bool _busy = false;

  String _initialPath() {
    final parts = widget.item.startLine.split(' ');
    return parts.length >= 2 ? parts[1] : '';
  }

  @override
  void dispose() {
    _method.dispose();
    _path.dispose();
    _status.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _resume() async {
    final item = widget.item;
    final edit = <String, dynamic>{
      'headers': (_headers.currentState?.headers ?? item.headers).map((h) => h.toJson()).toList(),
    };
    if (!item.isBinary) edit['bodyText'] = _body.text;
    if (item.isRequest) {
      edit['method'] = _method.text.trim();
      edit['path'] = _path.text.trim();
    } else {
      edit['status'] = int.tryParse(_status.text.trim()) ?? item.status;
    }
    setState(() => _busy = true);
    await ref.read(rulesProvider.notifier).resume(item.id, editJson: jsonEncode(edit));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _abort() async {
    setState(() => _busy = true);
    await ref.read(rulesProvider.notifier).abort(widget.item.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final item = widget.item;
    final stillPending = ref.watch(rulesProvider.select((s) => s.pending.any((e) => e.id == item.id)));
    final dec = AppComponents.input(p);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('bp_edit'))),
      body: !stillPending && !_busy
          ? Center(child: Text(t.t('bp_none_pending'), style: AppText.body(p)))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.pause, size: 16, color: AppColors.warningAmber),
                    const SizedBox(width: 10),
                    Text(item.isRequest ? t.t('phase_request') : t.t('phase_response'), style: AppText.heading(p)),
                    const SizedBox(width: 10),
                    MethodBadge(method: item.method, compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(item.url, style: AppText.mono(p, size: 12)),
                const SizedBox(height: AppSpacing.page),
                if (item.isRequest) ...[
                  Text(t.t('edit_method'), style: AppText.label(p)),
                  const SizedBox(height: 6),
                  TextField(controller: _method, style: AppText.mono(p), decoration: dec),
                  const SizedBox(height: 12),
                  Text(t.t('edit_path'), style: AppText.label(p)),
                  const SizedBox(height: 6),
                  TextField(controller: _path, style: AppText.mono(p), decoration: dec),
                ] else ...[
                  Text(t.t('edit_status'), style: AppText.label(p)),
                  const SizedBox(height: 6),
                  TextField(controller: _status, keyboardType: TextInputType.number, decoration: dec),
                ],
                SectionHeader(title: t.t('edit_headers')),
                HeaderEditor(key: _headers, initial: item.headers, addLabel: t.t('add_header')),
                SectionHeader(title: t.t('body')),
                if (item.isBinary)
                  Text(t.t('binary_body'), style: AppText.caption(p))
                else
                  TextField(controller: _body, minLines: 5, maxLines: 16, style: AppText.mono(p), decoration: dec),
                const SizedBox(height: AppSpacing.page),
                Row(
                  children: [
                    Expanded(
                      child: SkyButton(
                        label: t.t('bp_abort'),
                        secondary: true,
                        danger: true,
                        icon: const FaIcon(FontAwesomeIcons.ban),
                        onPressed: _busy ? null : _abort,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SkyButton(
                        label: t.t('bp_resume'),
                        icon: const FaIcon(FontAwesomeIcons.play),
                        loading: _busy,
                        onPressed: _resume,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
