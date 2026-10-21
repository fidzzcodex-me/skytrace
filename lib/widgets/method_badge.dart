import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

Color methodColor(String method) {
  switch (method.toUpperCase()) {
    case 'GET':
      return AppColors.primaryBlue;
    case 'POST':
      return AppColors.successGreen;
    case 'PUT':
      return AppColors.warningAmber;
    case 'PATCH':
      return AppColors.deepBlue;
    case 'DELETE':
      return AppColors.errorRed;
    case 'BLOCKED':
      return AppColors.warningAmber;
    default:
      return AppColors.textSecondary;
  }
}

class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.method, this.compact = false});

  final String method;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = methodColor(method);
    final label = method.length > 7 ? method.substring(0, 7) : method;
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 38 : 48),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label.toUpperCase(),
        style: AppText.label(Theme.of(context).extension<AppPalette>() ?? AppPalette.light)
            .copyWith(color: color, fontWeight: FontWeight.w800, fontSize: compact ? 10 : 11),
      ),
    );
  }
}
