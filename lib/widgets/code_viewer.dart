import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class CodeViewer extends StatefulWidget {
  const CodeViewer({
    super.key,
    required this.text,
    this.copyLabel = 'Copy',
    this.copiedLabel = 'Copied',
    this.moreLabel = 'Show all',
    this.previewLimit = 60000,
  });

  final String text;
  final String copyLabel;
  final String copiedLabel;
  final String moreLabel;
  final int previewLimit;

  @override
  State<CodeViewer> createState() => _CodeViewerState();
}

class _CodeViewerState extends State<CodeViewer> {
  bool _full = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tooLong = widget.text.length > widget.previewLimit;
    final shown = tooLong && !_full ? widget.text.substring(0, widget.previewLimit) : widget.text;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surfaceAlt.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: p.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: widget.text));
                messenger.showSnackBar(SnackBar(content: Text(widget.copiedLabel), duration: const Duration(seconds: 1)));
              },
              icon: const FaIcon(FontAwesomeIcons.copy, size: 12),
              label: Text(widget.copyLabel),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: p.brand,
                textStyle: AppText.label(p).copyWith(color: p.brand),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.inner, 0, AppSpacing.inner, AppSpacing.inner),
            child: SelectableText(shown, style: AppText.mono(p)),
          ),
          if (tooLong && !_full)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.inner, 0, AppSpacing.inner, AppSpacing.inner),
              child: TextButton(
                onPressed: () => setState(() => _full = true),
                child: Text(widget.moreLabel),
              ),
            ),
        ],
      ),
    );
  }
}
