import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';

class SkyButton extends StatelessWidget {
  const SkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.loading = false,
    this.danger = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool secondary;
  final bool loading;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(AppRadius.control);
    final textColor = secondary ? (danger ? AppColors.errorRed : p.brand) : AppColors.cloudWhite;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
          )
        else if (icon != null)
          IconTheme(data: IconThemeData(color: textColor, size: 15), child: icon!),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.button().copyWith(color: textColor),
          ),
        ),
      ],
    );

    final decoration = secondary
        ? BoxDecoration(
            color: p.surface,
            borderRadius: radius,
            border: Border.all(
              color: (danger ? AppColors.errorRed : AppColors.primaryBlue).withOpacity(0.35),
              width: 1,
            ),
          )
        : BoxDecoration(
            gradient: danger ? null : AppComponents.primaryGradient,
            color: danger ? AppColors.errorRed : null,
            borderRadius: radius,
            boxShadow: enabled ? AppComponents.softShadow(p) : null,
          );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
