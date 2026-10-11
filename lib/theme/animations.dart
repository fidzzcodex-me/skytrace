import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'colors.dart';

extension AosAnimate on Widget {
  Widget fadeInUp({int index = 0, double distance = 14}) {
    final delay = AppMotion.stagger * (index > 12 ? 12 : index);
    return animate(delay: delay)
        .fadeIn(duration: AppMotion.base, curve: AppMotion.curve)
        .slideY(begin: distance / 100, end: 0, duration: AppMotion.base, curve: AppMotion.curve);
  }

  Widget fadeInSoft({Duration delay = Duration.zero}) {
    return animate(delay: delay).fadeIn(duration: AppMotion.fast, curve: AppMotion.curve);
  }

  Widget scaleIn({Duration delay = Duration.zero}) {
    return animate(delay: delay)
        .fadeIn(duration: AppMotion.fast, curve: AppMotion.curve)
        .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), duration: AppMotion.fast, curve: AppMotion.curve);
  }
}

class SlideFromRightRoute<T> extends PageRouteBuilder<T> {
  SlideFromRightRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: AppMotion.base,
          reverseTransitionDuration: AppMotion.fast,
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
        );
}

class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: AppMotion.slow,
          reverseTransitionDuration: AppMotion.fast,
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
              child: child,
            );
          },
        );
}

Future<T?> showScaleDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withOpacity(0.28),
    transitionDuration: AppMotion.fast,
    pageBuilder: (ctx, a, b) => builder(ctx),
    transitionBuilder: (ctx, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(curved), child: child),
      );
    },
  );
}
