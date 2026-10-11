import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: FaIcon(icon, size: 30, color: AppColors.primaryBlue),
            ).scaleIn(),
            const SizedBox(height: 20),
            Text(title, style: AppText.heading(p), textAlign: TextAlign.center).fadeInUp(index: 1),
            const SizedBox(height: 6),
            Text(body, style: AppText.caption(p).copyWith(fontSize: 13), textAlign: TextAlign.center)
                .fadeInUp(index: 2),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!.fadeInUp(index: 3),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.circleExclamation, size: 30, color: AppColors.errorRed),
            const SizedBox(height: 12),
            Text(message, style: AppText.body(p), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
