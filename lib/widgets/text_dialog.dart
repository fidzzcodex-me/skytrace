import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/strings.dart';

Future<String?> showTextListDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
  required Strings strings,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showScaleDialog<String>(
    context: context,
    builder: (ctx) {
      final p = ctx.palette;
      return Center(
        child: Material(
          color: p.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(AppSpacing.page + 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.heading(p)),
                const SizedBox(height: 6),
                Text(hint, style: AppText.label(p)),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  style: AppText.mono(p, size: 13),
                  decoration: AppComponents.input(p),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(strings.t('cancel'))),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: Text(strings.t('save'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  controller.dispose();
  return result;
}

int countEntries(String raw) => raw.split(RegExp(r'[\n,; ]+')).where((e) => e.trim().isNotEmpty).length;
