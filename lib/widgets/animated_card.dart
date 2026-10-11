import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';

class AnimatedCard extends StatelessWidget {
  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.index = 0,
    this.padding = const EdgeInsets.all(AppSpacing.page),
    this.animate = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int index;
  final EdgeInsetsGeometry padding;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = Container(
      decoration: AppComponents.card(p),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return animate ? card.fadeInUp(index: index) : card;
  }
}
