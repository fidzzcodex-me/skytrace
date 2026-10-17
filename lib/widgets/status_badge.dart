import 'package:flutter/material.dart';

import '../models/traffic.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

Color statusColor(TrafficSummary t) {
  if (t.isFailed) return AppColors.errorRed;
  if (t.tunnel) return AppColors.textSecondary;
  if (t.isPending) return AppColors.textSecondary;
  final c = t.statusCode;
  if (c >= 500) return AppColors.errorRed;
  if (c >= 400) return AppColors.warningAmber;
  if (c >= 300) return AppColors.deepBlue;
  if (c >= 200) return AppColors.successGreen;
  return AppColors.textSecondary;
}

Color statusColorForCode(int code, {bool failed = false}) {
  if (failed) return AppColors.errorRed;
  if (code >= 500) return AppColors.errorRed;
  if (code >= 400) return AppColors.warningAmber;
  if (code >= 300) return AppColors.deepBlue;
  if (code >= 200) return AppColors.successGreen;
  return AppColors.textSecondary;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  factory StatusBadge.forTraffic(TrafficSummary t) {
    final label = t.isFailed
        ? 'ERR'
        : t.tunnel
            ? 'TUN'
            : t.isPending
                ? '...'
                : t.statusCode.toString();
    return StatusBadge(label: label, color: statusColor(t));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.label(Theme.of(context).extension<AppPalette>() ?? AppPalette.light)
            .copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
