import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.page, bottom: AppSpacing.tight),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.heading(p))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
