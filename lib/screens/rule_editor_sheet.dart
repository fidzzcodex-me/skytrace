import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rule.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/sky_button.dart';

const List<String> _methods = ['*', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'];

Future<RewriteRule?> showRuleEditor(BuildContext context, RewriteRule initial) {
  return showModalBottomSheet<RewriteRule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RuleEditor(initial: initial),
  );
}

Future<BreakpointRule?> showBreakpointEditor(BuildContext context, BreakpointRule initial) {
  return showModalBottomSheet<BreakpointRule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BreakpointEditor(initial: initial),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label(p)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _RuleEditor extends ConsumerStatefulWidget {
  const _RuleEditor({required this.initial});

  final RewriteRule initial;

  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  late RewriteRule _rule = widget.initial;
  late final TextEditingController _name = TextEditingController(text: widget.initial.name);
  late final TextEditingController _url = TextEditingController(text: widget.initial.urlPattern);
  late final TextEditingController _redirect = TextEditingController(text: widget.initial.redirectUrl);
  late final TextEditingController _headerName = TextEditingController(text: widget.initial.headerName);
  late final TextEditingController _headerValue = TextEditingController(text: widget.initial.headerValue);
  late final TextEditingController _find = TextEditingController(text: widget.initial.bodyFind);
  late final TextEditingController _replace = TextEditingController(text: widget.initial.bodyReplace);
  late final TextEditingController _mockStatus = TextEditingController(text: widget.initial.mockStatus.toString());
  late final TextEditingController _mockType = TextEditingController(text: widget.initial.mockContentType);
  late final TextEditingController _mockBody = TextEditingController(text: widget.initial.mockBody);
  late final TextEditingController _delay = TextEditingController(text: widget.initial.delayMs.toString());

  @override
  void dispose() {
    for (final c in [_name, _url, _redirect, _headerName, _headerValue, _find, _replace, _mockStatus, _mockType, _mockBody, _delay]) {
      c.dispose();
    }
    super.dispose();
  }

  RewriteRule _collect() {
    return _rule.copyWith(
      name: _name.text.trim(),
      urlPattern: _url.text.trim().isEmpty ? '*' : _url.text.trim(),
      redirectUrl: _redirect.text.trim(),
      headerName: _headerName.text.trim(),
      headerValue: _headerValue.text,
      bodyFind: _find.text,
      bodyReplace: _replace.text,
      mockStatus: int.tryParse(_mockStatus.text.trim()) ?? 200,
      mockContentType: _mockType.text.trim().isEmpty ? 'application/json' : _mockType.text.trim(),
      mockBody: _mockBody.text,
      delayMs: int.tryParse(_delay.text.trim()) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final dec = AppComponents.input(p);
    final action = _rule.action;
    final phaseApplies = action != RuleAction.redirect && action != RuleAction.mock;

    String actionLabel(RuleAction a) {
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
            children: [
              Text(widget.initial.id == 0 ? t.t('rule_new') : t.t('rule_edit'), style: AppText.title(p)),
              const SizedBox(height: AppSpacing.page),
              _Field(label: t.t('rule_name'), child: TextField(controller: _name, decoration: dec)),
              _Field(
                label: t.t('rule_url'),
                child: TextField(controller: _url, style: AppText.mono(p), decoration: dec),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.t('rule_regex'), style: AppText.body(p)),
                value: _rule.isRegex,
                onChanged: (v) => setState(() => _rule = _rule.copyWith(isRegex: v)),
              ),
              _Field(
                label: t.t('rule_method'),
                child: DropdownButtonFormField<String>(
                  value: _methods.contains(_rule.method) ? _rule.method : '*',
                  decoration: dec,
                  items: [for (final m in _methods) DropdownMenuItem(value: m, child: Text(m == '*' ? t.t('all') : m))],
                  onChanged: (v) => setState(() => _rule = _rule.copyWith(method: v ?? '*')),
                ),
              ),
              _Field(
                label: t.t('rule_action'),
                child: DropdownButtonFormField<RuleAction>(
                  value: action,
                  decoration: dec,
                  items: [for (final a in RuleAction.values) DropdownMenuItem(value: a, child: Text(actionLabel(a)))],
                  onChanged: (v) => setState(() => _rule = _rule.copyWith(action: v ?? action)),
                ),
              ),
              if (phaseApplies)
                _Field(
                  label: t.t('rule_phase'),
                  child: SegmentedButton<RulePhase>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: RulePhase.request, label: Text(t.t('phase_request'))),
                      ButtonSegment(value: RulePhase.response, label: Text(t.t('phase_response'))),
                    ],
                    selected: {_rule.phase},
                    onSelectionChanged: (s) => setState(() => _rule = _rule.copyWith(phase: s.first)),
                  ),
                ),
              if (action == RuleAction.redirect)
                _Field(
                  label: t.t('redirect_to'),
                  child: TextField(controller: _redirect, style: AppText.mono(p), decoration: dec),
                ),
              if (action == RuleAction.modifyHeader) ...[
                _Field(
                  label: t.t('header_op'),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'set', label: Text('set')),
                      ButtonSegment(value: 'add', label: Text('add')),
                      ButtonSegment(value: 'remove', label: Text('remove')),
                    ],
                    selected: {_rule.headerOp},
                    onSelectionChanged: (s) => setState(() => _rule = _rule.copyWith(headerOp: s.first)),
                  ),
                ),
                _Field(label: t.t('header_name'), child: TextField(controller: _headerName, style: AppText.mono(p), decoration: dec)),
                if (_rule.headerOp != 'remove')
                  _Field(label: t.t('header_value'), child: TextField(controller: _headerValue, style: AppText.mono(p), decoration: dec)),
              ],
              if (action == RuleAction.replaceBody) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.t('rule_regex'), style: AppText.body(p)),
                  value: _rule.bodyRegex,
                  onChanged: (v) => setState(() => _rule = _rule.copyWith(bodyRegex: v)),
                ),
                _Field(label: t.t('body_find'), child: TextField(controller: _find, style: AppText.mono(p), decoration: dec)),
                _Field(
                  label: t.t('body_replace'),
                  child: TextField(controller: _replace, minLines: 2, maxLines: 6, style: AppText.mono(p), decoration: dec),
                ),
              ],
              if (action == RuleAction.mock) ...[
                _Field(
                  label: t.t('mock_status'),
                  child: TextField(controller: _mockStatus, keyboardType: TextInputType.number, decoration: dec),
                ),
                _Field(label: t.t('mock_type'), child: TextField(controller: _mockType, style: AppText.mono(p), decoration: dec)),
                _Field(
                  label: t.t('mock_body'),
                  child: TextField(controller: _mockBody, minLines: 4, maxLines: 12, style: AppText.mono(p), decoration: dec),
                ),
              ],
              if (action == RuleAction.delay)
                _Field(
                  label: t.t('delay_ms'),
                  child: TextField(controller: _delay, keyboardType: TextInputType.number, decoration: dec),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SkyButton(label: t.t('cancel'), secondary: true, onPressed: () => Navigator.of(context).pop()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SkyButton(label: t.t('save'), onPressed: () => Navigator.of(context).pop(_collect())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakpointEditor extends ConsumerStatefulWidget {
  const _BreakpointEditor({required this.initial});

  final BreakpointRule initial;

  @override
  ConsumerState<_BreakpointEditor> createState() => _BreakpointEditorState();
}

class _BreakpointEditorState extends ConsumerState<_BreakpointEditor> {
  late BreakpointRule _bp = widget.initial;
  late final TextEditingController _name = TextEditingController(text: widget.initial.name);
  late final TextEditingController _url = TextEditingController(text: widget.initial.urlPattern);

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final dec = AppComponents.input(p);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
          children: [
            Text(widget.initial.id == 0 ? t.t('rule_new') : t.t('rule_edit'), style: AppText.title(p)),
            const SizedBox(height: AppSpacing.page),
            _Field(label: t.t('rule_name'), child: TextField(controller: _name, decoration: dec)),
            _Field(label: t.t('rule_url'), child: TextField(controller: _url, style: AppText.mono(p), decoration: dec)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.t('rule_regex'), style: AppText.body(p)),
              value: _bp.isRegex,
              onChanged: (v) => setState(() => _bp = _bp.copyWith(isRegex: v)),
            ),
            _Field(
              label: t.t('rule_method'),
              child: DropdownButtonFormField<String>(
                value: _methods.contains(_bp.method) ? _bp.method : '*',
                decoration: dec,
                items: [for (final m in _methods) DropdownMenuItem(value: m, child: Text(m == '*' ? t.t('all') : m))],
                onChanged: (v) => setState(() => _bp = _bp.copyWith(method: v ?? '*')),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.t('bp_on_request'), style: AppText.body(p)),
              value: _bp.onRequest,
              onChanged: (v) => setState(() => _bp = _bp.copyWith(onRequest: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.t('bp_on_response'), style: AppText.body(p)),
              value: _bp.onResponse,
              onChanged: (v) => setState(() => _bp = _bp.copyWith(onResponse: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SkyButton(label: t.t('cancel'), secondary: true, onPressed: () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkyButton(
                    label: t.t('save'),
                    onPressed: () => Navigator.of(context).pop(
                      _bp.copyWith(
                        name: _name.text.trim(),
                        urlPattern: _url.text.trim().isEmpty ? '*' : _url.text.trim(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
