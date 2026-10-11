import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.primaryBlue,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.inner),
      decoration: AppComponents.card(p),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: FaIcon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.heading(p)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(p)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
