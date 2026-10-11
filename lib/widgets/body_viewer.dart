import 'package:flutter/material.dart';

import '../models/response.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import '../utils/json_pretty.dart';
import '../utils/strings.dart';
import 'code_viewer.dart';
import 'json_tree_view.dart';

class BodyViewer extends StatefulWidget {
  const BodyViewer({super.key, required this.body, required this.strings});

  final BodyView body;
  final Strings strings;

  @override
  State<BodyViewer> createState() => _BodyViewerState();
}

class _BodyViewerState extends State<BodyViewer> {
  bool _tree = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = widget.strings;
    final b = widget.body;
    if (b.isEmpty) {
      return Text(t.t('no_body'), style: AppText.caption(p));
    }
    final children = <Widget>[
      Text(
        '${Fmt.bytes(b.size)}  |  ${Fmt.shortType(b.contentType)}${b.encoding.isNotEmpty ? '  |  ${b.encoding}' : ''}',
        style: AppText.label(p),
      ),
      const SizedBox(height: 8),
    ];
    if (b.truncated) {
      children.add(Text(t.t('truncated'), style: AppText.caption(p).copyWith(color: AppColors.warningAmber)));
      children.add(const SizedBox(height: 8));
    }
    if (b.isBinary) {
      children.add(Text(t.t('binary_body'), style: AppText.bodyMedium(p)));
      children.add(const SizedBox(height: 8));
      if (b.base64.isNotEmpty) {
        children.add(CodeViewer(
          text: b.base64,
          copyLabel: t.t('copy'),
          copiedLabel: t.t('copied'),
          previewLimit: 4000,
        ));
      }
    } else {
      final text = b.text;
      final isJson = JsonPretty.looksJson(b.contentType, text);
      final pretty = isJson ? JsonPretty.tryFormat(text) : null;
      final decoded = pretty != null && _tree ? JsonPretty.tryDecode(text) : null;
      if (pretty != null) {
        children.add(
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment<bool>(value: false, label: Text(t.t('text_view'))),
                ButtonSegment<bool>(value: true, label: Text(t.t('tree_view'))),
              ],
              selected: {_tree},
              onSelectionChanged: (s) => setState(() => _tree = s.first),
            ),
          ),
        );
        children.add(const SizedBox(height: 10));
      }
      if (_tree && decoded != null) {
        children.add(JsonTreeView(data: decoded));
      } else {
        children.add(CodeViewer(
          text: pretty ?? text,
          copyLabel: t.t('copy'),
          copiedLabel: t.t('copied'),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
