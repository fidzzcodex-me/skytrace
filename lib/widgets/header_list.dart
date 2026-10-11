import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/request.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class HeaderList extends StatelessWidget {
  const HeaderList({super.key, required this.headers, required this.copiedLabel});

  final List<HeaderPair> headers;
  final String copiedLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        for (final h in headers)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onLongPress: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: '${h.name}: ${h.value}'));
              messenger.showSnackBar(SnackBar(content: Text(copiedLabel), duration: const Duration(seconds: 1)));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      h.name,
                      style: AppText.bodyMedium(p).copyWith(color: p.brandStrong, fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(h.value, style: AppText.mono(p, size: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
