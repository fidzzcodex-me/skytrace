import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class JsonTreeView extends StatelessWidget {
  const JsonTreeView({super.key, required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.inner),
      decoration: BoxDecoration(
        color: p.surfaceAlt.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: p.surfaceAlt),
      ),
      child: _JsonNode(label: null, value: data, depth: 0),
    );
  }
}

class _JsonNode extends StatefulWidget {
  const _JsonNode({required this.label, required this.value, required this.depth});

  final String? label;
  final dynamic value;
  final int depth;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _open = widget.depth < 1;
  int _limit = 100;

  bool get _isContainer => widget.value is Map || widget.value is List;

  Color _valueColor(dynamic v) {
    if (v is String) return AppColors.successGreen;
    if (v is num) return AppColors.primaryBlue;
    if (v is bool) return AppColors.warningAmber;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = AppText.mono(p);
    final keyStyle = style.copyWith(color: p.brandStrong, fontWeight: FontWeight.w600);

    if (!_isContainer) {
      final v = widget.value;
      final shown = v is String ? '"$v"' : '$v';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SelectableText.rich(
          TextSpan(
            children: [
              if (widget.label != null) TextSpan(text: '${widget.label}: ', style: keyStyle),
              TextSpan(text: shown, style: style.copyWith(color: _valueColor(v))),
            ],
          ),
        ),
      );
    }

    final isMap = widget.value is Map;
    final entries = isMap
        ? (widget.value as Map).entries.map((e) => MapEntry(e.key.toString(), e.value)).toList()
        : (widget.value as List).asMap().entries.map((e) => MapEntry('${e.key}', e.value)).toList();
    final summary = isMap ? '{${entries.length}}' : '[${entries.length}]';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const FaIcon(FontAwesomeIcons.chevronDown, size: 10, color: AppColors.textMuted),
                ),
                const SizedBox(width: 6),
                if (widget.label != null) Text('${widget.label}: ', style: keyStyle),
                Text(summary, style: style.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries.take(_limit))
                  _JsonNode(label: e.key, value: e.value, depth: widget.depth + 1),
                if (entries.length > _limit)
                  TextButton(
                    onPressed: () => setState(() => _limit += 200),
                    child: Text('+ ${entries.length - _limit}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
